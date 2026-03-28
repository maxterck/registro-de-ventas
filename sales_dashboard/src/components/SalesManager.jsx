import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabaseClient';
import { ShoppingCart, DollarSign, Filter, Loader2, ArrowUpRight, Trash2, Edit, CheckCircle2 } from 'lucide-react';

export default function SalesManager({ storeId }) {
  const [sales, setSales] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all');
  const [selectedEmployee, setSelectedEmployee] = useState('Todos');
  const [showHistorial, setShowHistorial] = useState(false);

  useEffect(() => {
    if (storeId) loadSales();
  }, [storeId]);

  const loadSales = async () => {
    setLoading(true);
    const { data } = await supabase
       .from('sales')
       .select('*, access_keys(employee_name)')
       .eq('store_id', storeId)
       .order('timestamp', { ascending: false });
       
    if (data) setSales(data);
    setLoading(false);
  };

  const voidSale = async (s) => {
     if (s.is_voided) return;
     const reason = prompt('Escribí el motivo por el que anulás esta venta:');
     if (reason === null) return;
     if (reason.trim() === '') { alert('El motivo es obligatorio para anular.'); return; }

     if(confirm('¿Confirmar anulación? El dinero no contará en los balances ni deudas.')) {
        const { data, error } = await supabase.from('sales')
             .update({ is_voided: true, cancel_reason: reason })
             .eq('id', s.id)
             .select('*, access_keys(employee_name)')
             .single();
        if(data) {
           setSales(sales.map(sale => sale.id === s.id ? data : sale));
        } else {
           alert('Error al anular. (Asegúrate de haber ejecutado el SQL en Supabase para crear las columnas is_voided y cancel_reason)');
        }
     }
  };

  const toggleDebtStatus = async (sale) => {
     if (sale.is_voided) { alert('No puedes modificar una venta anulada.'); return; }
     
     const isCurrentlyDebt = sale.is_debt;
     const newPaymentMethod = isCurrentlyDebt ? 'cash' : 'credit';
     
     if (isCurrentlyDebt) {
        // Pasando a pagado (efectivo)
        if(confirm('¿Pasar Venta a Pagada (Efectivo)?')) {
           const { data, error } = await supabase.from('sales')
                .update({ is_debt: false, payment_method: 'cash' })
                .eq('id', sale.id)
                .select('*, access_keys(employee_name)')
                .single();
           if(!error && data) setSales(sales.map(s => s.id === sale.id ? data : s));
        }
     } else {
        // Pasando a deuda (fiado)
        const customerToken = prompt('Para marcar como fiado, ingresa el Nombre o Token del cliente:');
        if (customerToken === null) return; // Canceló
        
        const finalCustomerName = customerToken.trim() === '' ? 'Cliente sin registrar' : customerToken.trim();

        const { data, error } = await supabase.from('sales')
             .update({ is_debt: true, payment_method: 'credit', customer_name: finalCustomerName })
             .eq('id', sale.id)
             .select('*, access_keys(employee_name)')
             .single();
             
        if(!error && data) setSales(sales.map(s => s.id === sale.id ? data : s));
     }
  };

  const baseFiltered = filter === 'all' ? sales : 
                        filter === 'voided' ? sales.filter(s => s.is_voided) : 
                        sales.filter(s => s.payment_method === filter && !s.is_voided);

  const filteredSales = selectedEmployee === 'Todos' 
                        ? baseFiltered 
                        : baseFiltered.filter(s => (s.access_keys?.employee_name || 'Dueño 👑') === selectedEmployee);

  const uniqueEmployees = ['Todos', ...new Set(sales.map(s => s.access_keys?.employee_name || 'Dueño 👑'))];
                        
  const totalRevenue = filteredSales.reduce((sum, sale) => sum + (sale.is_voided ? 0 : Number(sale.amount)), 0);

  const todayRevenue = filteredSales.filter(s => {
      const isToday = new Date(s.timestamp).toLocaleDateString() === new Date().toLocaleDateString();
      return isToday && !s.is_voided;
  }).reduce((sum, sale) => sum + Number(sale.amount), 0);

  const thisWeekRevenue = filteredSales.filter(s => {
      if(s.is_voided) return false;
      const d = new Date(s.timestamp);
      const diffTime = new Date() - d;
      const diffDays = diffTime / (1000 * 60 * 60 * 24); 
      return diffDays <= 7 && diffDays >= 0;
  }).reduce((sum, sale) => sum + Number(sale.amount), 0);

  const thisMonthRevenue = filteredSales.filter(s => {
      if(s.is_voided) return false;
      const d = new Date(s.timestamp);
      return d.getMonth() === new Date().getMonth() && d.getFullYear() === new Date().getFullYear();
  }).reduce((sum, sale) => sum + Number(sale.amount), 0);

  const exportToCSV = () => {
     if(filteredSales.length === 0) return alert('No hay datos para exportar');
     
     const headers = ['ID Registro', 'Producto', 'Monto', 'Metodo Pago', 'Cliente', 'Cajero', 'Fecha', 'Estado'];
     const rows = filteredSales.map(s => [
         s.id,
         `"${s.product_name_snapshot}"`,
         s.amount,
         translateMethod(s.payment_method),
         `"${s.customer_name || 'Consumidor Final'}"`,
         `"${s.access_keys?.employee_name || 'Dueño 👑'}"`,
         `"${new Date(s.timestamp).toLocaleString('es-ES')}"`,
         s.is_voided ? 'Anulada' : 'Confirmada'
     ]);
     
     const csvContent = "data:text/csv;charset=utf-8," + [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
     const encodedUri = encodeURI(csvContent);
     const link = document.createElement('a');
     link.setAttribute('href', encodedUri);
     link.setAttribute('download', `reporte_ventas_${filter}_${new Date().toISOString().slice(0,10)}.csv`);
     document.body.appendChild(link);
     link.click();
     document.body.removeChild(link);
  };

  const translateMethod = (method) => {
     if (method === 'cash') return 'Efectivo';
     if (method === 'transfer') return 'Transferencia';
     if (method === 'credit') return 'Crédito/Fiado';
     return method;
  };

  const formatDate = (isoString) => {
     const d = new Date(isoString);
     return d.toLocaleDateString('es-ES') + ' ' + d.toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' });
  };

  return (
    <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500">
      <div className="flex items-center justify-between">
         <div className="flex items-center gap-3">
           <ShoppingCart className="w-8 h-8 text-indigo-400" />
           <h1 className="text-3xl font-bold tracking-tight text-white">Registro de Ventas</h1>
         </div>
      </div>
      
      <p className="text-slate-400 max-w-2xl text-lg">
        Visualiza y edita todas las transacciones realizadas. Puedes eliminar errores del cajero o cancelar deudas manuales desde la columna de Acciones.
      </p>

      {/* KPI Cards */}
      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4 mt-6 mb-2">
         <div className="bg-[#161b22] border border-slate-800 rounded-3xl p-5 shadow-xl relative overflow-hidden">
            <div className="absolute top-0 right-0 w-24 h-24 bg-emerald-500/10 rounded-full blur-2xl -mr-10 -mt-10"></div>
            <p className="text-slate-400 font-medium mb-1 text-xs uppercase tracking-widest block">Facturado Hoy</p>
            <h3 className="text-2xl lg:text-3xl font-bold text-white flex items-center gap-1.5 relative z-10">
               <span className="text-emerald-400">$</span>{todayRevenue.toFixed(2)}
            </h3>
         </div>

         <div className="bg-[#161b22] border border-slate-800 rounded-3xl p-5 shadow-xl relative overflow-hidden">
            <div className="absolute top-0 right-0 w-24 h-24 bg-blue-500/10 rounded-full blur-2xl -mr-10 -mt-10"></div>
            <p className="text-slate-400 font-medium mb-1 text-xs uppercase tracking-widest block">Últimos 7 Días</p>
            <h3 className="text-2xl lg:text-3xl font-bold text-white flex items-center gap-1.5 relative z-10">
               <span className="text-blue-400">$</span>{thisWeekRevenue.toFixed(2)}
            </h3>
         </div>

         <div className="bg-[#161b22] border border-slate-800 rounded-3xl p-5 shadow-xl relative overflow-hidden">
            <div className="absolute top-0 right-0 w-24 h-24 bg-purple-500/10 rounded-full blur-2xl -mr-10 -mt-10"></div>
            <p className="text-slate-400 font-medium mb-1 text-xs uppercase tracking-widest block">Este Mes</p>
            <h3 className="text-2xl lg:text-3xl font-bold text-white flex items-center gap-1.5 relative z-10">
               <span className="text-purple-400">$</span>{thisMonthRevenue.toFixed(2)}
            </h3>
         </div>

         <div className="bg-[#161b22] border border-slate-800 rounded-3xl p-5 shadow-xl relative overflow-hidden">
            <div className="absolute top-0 right-0 w-24 h-24 bg-indigo-500/20 rounded-full blur-2xl -mr-10 -mt-10"></div>
            <p className="text-slate-400 font-medium mb-1 text-xs uppercase tracking-widest block">Histórico Total</p>
            <h3 className="text-2xl lg:text-3xl font-bold text-white flex items-center gap-1.5 relative z-10">
               <span className="text-indigo-400">$</span>{totalRevenue.toFixed(2)}
            </h3>
         </div>
      </div>

      {/* Filtros */}
      <div className="flex flex-wrap items-start justify-between gap-4 mb-6">
         <div className="flex flex-col gap-3 z-10">
           <div className="flex flex-wrap items-center gap-2 bg-[#161b22] p-2 rounded-2xl border border-slate-800 shadow-lg">
              <Filter className="w-5 h-5 text-slate-400 ml-3 mr-2" />
              <button onClick={() => setFilter('all')} className={`px-4 py-2 rounded-xl text-sm font-semibold transition-all ${filter === 'all' ? 'bg-indigo-600 text-white' : 'text-slate-400 hover:text-white hover:bg-white/5'}`}>Todas</button>
              <button onClick={() => setFilter('cash')} className={`px-4 py-2 rounded-xl text-sm font-semibold transition-all ${filter === 'cash' ? 'bg-emerald-600 text-white' : 'text-slate-400 hover:text-white hover:bg-white/5'}`}>Efectivo</button>
              <button onClick={() => setFilter('transfer')} className={`px-4 py-2 rounded-xl text-sm font-semibold transition-all ${filter === 'transfer' ? 'bg-blue-600 text-white' : 'text-slate-400 hover:text-white hover:bg-white/5'}`}>Transferencia</button>
              <button onClick={() => setFilter('credit')} className={`px-4 py-2 rounded-xl text-sm font-semibold transition-all ${filter === 'credit' ? 'bg-orange-600 text-white' : 'text-slate-400 hover:text-white hover:bg-white/5'}`}>Fiados</button>
              <div className="w-px h-6 bg-slate-700 mx-2"></div>
              <button onClick={() => setFilter('voided')} className={`px-4 py-2 rounded-xl text-sm font-semibold transition-all ${filter === 'voided' ? 'bg-rose-600 text-white' : 'text-slate-400 hover:text-white hover:bg-white/5'}`}>Auditoría Anuladas</button>
           </div>
           
           <div className="flex flex-wrap items-center gap-2 bg-[#161b22] p-2 rounded-2xl border border-slate-800 shadow-lg w-max">
             <span className="text-slate-400 ml-3 text-sm font-semibold">Cajero:</span>
             <select
                className="bg-[#0b0f14] text-white px-4 py-1.5 rounded-xl outline-none border border-slate-800 hover:border-indigo-500 transition-colors w-48 text-sm cursor-pointer"
                value={selectedEmployee}
                onChange={(e) => setSelectedEmployee(e.target.value)}
             >
                {uniqueEmployees.map(e => <option key={e} value={e}>{e}</option>)}
             </select>
             
             <div className="w-px h-5 bg-slate-700 mx-2"></div>
             
             <button onClick={() => setShowHistorial(true)} className="bg-indigo-600 text-white px-4 py-1.5 rounded-xl text-sm font-semibold hover:bg-indigo-500 transition-all flex items-center gap-2 shadow-lg shadow-indigo-500/20 active:scale-95">
                <ArrowUpRight className="w-4 h-4"/>
                Historial Gráfico
             </button>
           </div>
         </div>

         <button onClick={exportToCSV} className="bg-[#161b22] border border-slate-700 hover:border-emerald-500 hover:bg-emerald-500/10 text-emerald-400 font-bold py-3 px-6 rounded-2xl transition-all shadow-lg flex items-center gap-2 active:scale-95">
           Exportar Excel (CSV)
         </button>
      </div>

      {/* Tabla */}
      <div className="bg-[#161b22] border border-slate-800 rounded-3xl overflow-hidden shadow-xl min-h-[160px]">
        {loading ? (
             <div className="flex justify-center items-center p-12"><Loader2 className="w-8 h-8 animate-spin text-indigo-500"/></div>
        ) : (
          <div className="overflow-x-auto">
             <table className="w-full text-left border-collapse min-w-max">
               <thead>
                 <tr className="bg-slate-800/40 text-slate-400 text-xs font-semibold uppercase tracking-wider border-b border-slate-800">
                   <th className="p-5">Producto Vendido</th>
                   <th className="p-5">Monto ($)</th>
                   <th className="p-5">Tipo de Pago</th>
                   <th className="p-5">Datos Cajero</th>
                   <th className="p-5 text-right">Acciones</th>
                 </tr>
               </thead>
               <tbody className="divide-y divide-slate-800/60">
                 {filteredSales.map((s) => (
                   <tr key={s.id} className={`hover:bg-white/[0.02] transition-colors group ${s.is_voided ? 'opacity-40 grayscale' : ''}`}>
                     <td className="p-5">
                         <div className="flex items-center gap-2">
                            <span className={`font-medium text-lg block ${s.is_voided ? 'line-through text-slate-500' : 'text-white'}`}>{s.product_name_snapshot}</span>
                            {s.is_voided && <span className="bg-rose-500/20 text-rose-400 text-[10px] font-bold px-2 py-0.5 rounded-full border border-rose-500/30">ANULADA</span>}
                         </div>
                         {s.is_debt && !s.is_voided && <span className="inline-flex mt-1 items-center text-xs font-bold bg-orange-500/10 text-orange-400 border border-orange-500/30 px-2 py-0.5 rounded-md shadow-sm">Cliente: {s.customer_name}</span>}
                         {s.is_voided && <p className="text-xs text-slate-400 mt-1">Motivo: {s.cancel_reason}</p>}
                     </td>
                     
                     {/* Monto */}
                     <td className="p-5 text-emerald-400 font-black tracking-wide text-xl">${Number(s.amount).toFixed(2)}</td>
                     
                     {/* Método Pago */}
                     <td className="p-5">
                        <span className={`inline-flex items-center px-3 py-1 rounded-full text-xs font-bold border ${!s.is_debt ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20' : 'bg-orange-500/10 text-orange-400 border-orange-500/30'}`}>
                            {translateMethod(s.payment_method)}
                        </span>
                     </td>

                     {/* Cajero / Fecha */}
                     <td className="p-5">
                         <p className="text-slate-300 font-medium whitespace-nowrap">{s.access_keys?.employee_name || 'Dueño 👑'}</p>
                         <p className="text-slate-500 text-xs mt-0.5">{formatDate(s.timestamp)}</p>
                     </td>
                     
                     {/* Acciones para Modificar/Anular */}
                     <td className="p-5 text-right flex items-center justify-end gap-2">
                        <button 
                             onClick={() => toggleDebtStatus(s)} 
                             disabled={s.is_voided}
                             className={`p-2.5 rounded-xl border transition-all ${
                                (s.is_voided || !s.is_debt) ? 'hidden' :
                                'bg-emerald-500/10 text-emerald-500 border-emerald-500/20 hover:bg-emerald-500 hover:text-white'
                             }`}
                             title="Revertir a Pagado Efectivo"
                        >
                           <CheckCircle2 className="w-5 h-5"/>
                        </button>
                        
                        <button 
                            onClick={() => voidSale(s)} 
                            disabled={s.is_voided}
                            className={`transition-colors p-2.5 rounded-xl border shadow-lg ${s.is_voided ? 'hidden' : 'text-slate-500 hover:text-white hover:bg-rose-600 bg-[#0b0f14] border-slate-700 hover:border-rose-500'}`}
                            title="Anular registro completamente"
                        >
                           <Trash2 className="w-5 h-5" />
                        </button>
                     </td>
                   </tr>
                 ))}
                 {filteredSales.length === 0 && (
                     <tr><td colSpan="5" className="p-12 text-center text-slate-500 text-lg">No hay ventas registradas que coincidan.</td></tr>
                 )}
               </tbody>
             </table>
          </div>
        )}
      </div>
      
      {/* Modal Historial Gráfico */}
      {showHistorial && (
         <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-in fade-in duration-200">
           <div className="bg-[#161b22] rounded-3xl w-full max-w-4xl overflow-hidden shadow-2xl border border-slate-700 outline outline-4 outline-slate-800/50">
             <div className="p-6 border-b border-slate-800 flex justify-between items-center bg-[#0d1117]">
                <h3 className="text-xl font-bold text-white flex items-center gap-2">
                   <ArrowUpRight className="w-5 h-5 text-indigo-400"/> Historial de Ventas ({new Date().toLocaleDateString('es-ES')})
                </h3>
                <button onClick={() => setShowHistorial(false)} className="bg-slate-800 hover:bg-slate-700 text-white rounded-full w-8 h-8 flex items-center justify-center transition-colors">✕</button>
             </div>
             <div className="p-6">
                <ScatterPlot data={baseFiltered} />
                <div className="flex gap-4 mt-6 justify-center bg-[#0b0f14] p-3 rounded-xl border border-slate-800 max-w-sm mx-auto">
                   <div className="flex items-center gap-2 text-sm font-bold text-sky-400"><span className="w-3 h-3 rounded-full bg-sky-400 shadow-[0_0_10px_rgba(56,189,248,0.8)]"></span> VENTA (Cobrada)</div>
                   <div className="w-px h-4 bg-slate-700"></div>
                   <div className="flex items-center gap-2 text-sm font-bold text-orange-400"><span className="w-3 h-3 rounded-full bg-orange-500 shadow-[0_0_10px_rgba(249,115,22,0.8)]"></span> FIADO (Deuda)</div>
                </div>
             </div>
           </div>
         </div>
      )}
    </div>
  );
}

function ScatterPlot({ data }) {
   if (!data || data.length === 0) return <p className="text-white text-center p-10 font-bold">No hay ventas para graficar</p>;

   const width = 800;
   const height = 300;
   const padding = 40;

   const activeData = data.filter(d => !d.is_voided);
   if (activeData.length === 0) return <p className="text-white text-center p-10 font-bold">Sin datos válidos</p>;
   
   const maxVal = Math.max(...activeData.map(d => Number(d.amount)), 100);

   const points = activeData.map(s => {
       const dt = new Date(s.timestamp);
       const timeFloat = dt.getHours() + (dt.getMinutes() / 60);
       const cx = padding + ((timeFloat / 24) * (width - padding * 2));
       const cy = height - padding - ((Number(s.amount) / maxVal) * (height - padding * 2));
       return { cx, cy, isDebt: s.is_debt, amount: s.amount, time: dt.toLocaleTimeString('es-ES', {hour:'2-digit', minute:'2-digit'})};
   });

   return (
       <div className="w-full overflow-x-auto custom-scrollbar bg-[#0b0f14] p-4 mx-auto rounded-2xl border border-slate-800">
          <style>{`
             @keyframes pulsePoint {
                0% { r: 5px; opacity: 1; stroke-width: 0; }
                100% { r: 10px; opacity: 0.6; stroke-width: 4px; stroke: rgba(255,255,255,0.4); }
             }
             .pulsing-dot { animation: pulsePoint 0.7s infinite alternate ease-in-out; }
          `}</style>
          <svg width={width} height={height} className="min-w-[800px]">
             {/* Y axis lines */}
             {[0, 1, 2, 3, 4].map(i => {
                const y = height - padding - ((i/4) * (height - padding * 2));
                const val = (maxVal * (i/4)).toFixed(0);
                return (
                   <g key={`y-${i}`}>
                     <line x1={padding} y1={y} x2={width-padding} y2={y} stroke="rgba(255,255,255,0.05)" />
                     <text x={padding - 5} y={y + 4} fill="rgba(255,255,255,0.4)" fontSize="10" textAnchor="end">${val}</text>
                   </g>
                );
             })}

             {/* X axis lines (hours) */}
             {[0, 4, 8, 12, 16, 20, 24].map(i => {
                const x = padding + ((i/24) * (width - padding * 2));
                return (
                   <g key={`x-${i}`}>
                     <line x1={x} y1={padding} x2={x} y2={height-padding} stroke="rgba(255,255,255,0.1)" />
                     <text x={x} y={height - padding + 15} fill="rgba(255,255,255,0.4)" fontSize="10" textAnchor="middle">{i}h</text>
                   </g>
                );
             })}

             {/* Points */}
             {points.map((p, i) => (
                <circle key={i} cx={p.cx} cy={p.cy} fill={p.isDebt ? '#f97316' : '#38bdf8'} className="pulsing-dot cursor-pointer cursor-crosshair">
                   <title>{`Monto: $${p.amount} | Hora: ${p.time}`}</title>
                </circle>
             ))}
          </svg>
       </div>
   );
}

import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabaseClient';
import { ShoppingCart, DollarSign, Filter, Loader2, ArrowUpRight, Trash2, Edit, CheckCircle2 } from 'lucide-react';

export default function SalesManager({ storeId }) {
  const [sales, setSales] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all');

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

  const filteredSales = filter === 'all' ? sales : sales.filter(s => s.payment_method === filter);
  const totalRevenue = filteredSales.reduce((sum, sale) => sum + (sale.is_voided ? 0 : Number(sale.amount)), 0);

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
      <div className="bg-[#161b22] border border-slate-800 rounded-3xl p-6 shadow-xl relative overflow-hidden mt-6 mb-2 max-w-md">
         <div className="absolute top-0 right-0 w-32 h-32 bg-emerald-500/10 rounded-full blur-2xl -mr-10 -mt-10"></div>
         <p className="text-slate-400 font-medium mb-1">Total del Filtro Seleccionado</p>
         <h3 className="text-4xl font-bold text-white flex items-center gap-2 relative z-10">
            <DollarSign className="w-8 h-8 text-emerald-400" />
            {totalRevenue.toFixed(2)}
         </h3>
         <p className="text-emerald-400 text-sm mt-3 flex items-center gap-1 font-medium relative z-10"><ArrowUpRight className="w-4 h-4"/> Sincronizado</p>
      </div>

      {/* Filtros */}
      <div className="flex flex-wrap items-center gap-2 bg-[#161b22] p-2 rounded-2xl border border-slate-800 w-max relative z-10 shadow-lg mb-8">
         <Filter className="w-5 h-5 text-slate-400 ml-3 mr-2" />
         <button onClick={() => setFilter('all')} className={`px-4 py-2 rounded-xl text-sm font-semibold transition-all ${filter === 'all' ? 'bg-indigo-600 text-white' : 'text-slate-400 hover:text-white hover:bg-white/5'}`}>Todas</button>
         <button onClick={() => setFilter('cash')} className={`px-4 py-2 rounded-xl text-sm font-semibold transition-all ${filter === 'cash' ? 'bg-emerald-600 text-white' : 'text-slate-400 hover:text-white hover:bg-white/5'}`}>Efectivo</button>
         <button onClick={() => setFilter('transfer')} className={`px-4 py-2 rounded-xl text-sm font-semibold transition-all ${filter === 'transfer' ? 'bg-blue-600 text-white' : 'text-slate-400 hover:text-white hover:bg-white/5'}`}>Transferencia</button>
         <button onClick={() => setFilter('credit')} className={`px-4 py-2 rounded-xl text-sm font-semibold transition-all ${filter === 'credit' ? 'bg-orange-600 text-white' : 'text-slate-400 hover:text-white hover:bg-white/5'}`}>Fiados</button>
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
                         <p className="text-slate-300 font-medium">{s.access_keys?.employee_name || 'Desconocido'}</p>
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
    </div>
  );
}

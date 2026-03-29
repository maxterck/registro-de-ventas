import React, { useState, useEffect } from 'react';
import { supabase } from '../lib/supabaseClient';
import { Loader2, PieChart as PieChartIcon, BarChart3, TrendingUp, DollarSign } from 'lucide-react';
import { PieChart, Pie, Cell, Tooltip as RechartsTooltip, ResponsiveContainer, BarChart, Bar, XAxis, YAxis, CartesianGrid, Legend } from 'recharts';

export default function AnalyticsManager({ storeId }) {
  const [sales, setSales] = useState([]);
  const [inventory, setInventory] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (storeId) loadData();
  }, [storeId]);

  const loadData = async () => {
    setLoading(true);
    // Traemos todo el historial de ventas
    const { data: salesData } = await supabase
      .from('sales')
      .select('amount, is_debt, payment_method, is_voided, timestamp, access_keys(employee_name), product_name_snapshot')
      .eq('store_id', storeId)
      .eq('is_voided', false);
      
    // Traemos el inventario actual para cruzar stock
    const { data: invData } = await supabase
      .from('products')
      .select('name, stock')
      .eq('store_id', storeId);

    if (salesData) setSales(salesData);
    if (invData) setInventory(invData);
    setLoading(false);
  };

  if (loading) {
     return <div className="flex-1 p-8 flex items-center justify-center"><Loader2 className="w-8 h-8 animate-spin text-indigo-500" /></div>;
  }

  // === CALCULOS PARA GRÁFICOS ===
  const totalRevenue = sales.filter(s => !s.is_debt).reduce((acc, s) => acc + Number(s.amount), 0);
  const totalDebt = sales.filter(s => s.is_debt).reduce((acc, s) => acc + Number(s.amount), 0);

  // 1. Dona: Efectivo vs Tarjeta vs Fiado
  const cashSales = sales.filter(s => !s.is_debt && s.payment_method === 'cash').reduce((acc, s) => acc + Number(s.amount), 0);
  const cardSales = sales.filter(s => !s.is_debt && s.payment_method === 'card').reduce((acc, s) => acc + Number(s.amount), 0);
  
  const paymentData = [
    { name: 'Efectivo/Transferencia', value: cashSales, color: '#4f46e5' },
    { name: 'Tarjeta/Digital', value: cardSales, color: '#0ea5e9' },
    { name: 'Fiado (Deuda)', value: totalDebt, color: '#f59e0b' }
  ].filter(d => d.value > 0);

  // 2. Gráfico de Barras: Ventas Top Empleados (Top 10)
  const employeeMap = {};
  sales.forEach(s => {
     if(s.is_debt) return;
     const name = s.access_keys?.employee_name || 'Dueño 👑';
     employeeMap[name] = (employeeMap[name] || 0) + Number(s.amount);
  });
  const employeeData = Object.keys(employeeMap)
     .map(name => ({ name, Ventas: employeeMap[name] }))
     .sort((a,b) => b.Ventas - a.Ventas)
     .slice(0, 10);

  // 3. Gráfico de Barras Temporal: Ventas últimos 7 días
  const last7DaysMap = {};
  for(let i=6; i>=0; i--) {
     const d = new Date();
     d.setDate(d.getDate() - i);
     last7DaysMap[d.toLocaleDateString('es-ES', { weekday: 'short', day: 'numeric'})] = 0;
  }

  sales.forEach(s => {
     if(s.is_debt) return;
     const saleDate = new Date(s.timestamp);
     const dateStr = saleDate.toLocaleDateString('es-ES', { weekday: 'short', day: 'numeric'});
     if(last7DaysMap[dateStr] !== undefined) {
         last7DaysMap[dateStr] += Number(s.amount);
     }
  });

  const timeData = Object.keys(last7DaysMap).map(date => ({
     fecha: date,
     Ingresos: last7DaysMap[date]
  }));

  // 4. Gráfico de Barras: Top 15 Productos vendidas vs Stock
  const productMap = {};
  sales.forEach(s => {
     if(s.is_debt) return;
     const prod = s.product_name_snapshot || 'Desconocido';
     productMap[prod] = (productMap[prod] || 0) + 1;
  });

  const productData = Object.keys(productMap)
     .map(name => {
        // Buscar stock cruzado
        const invItem = inventory.find(i => i.name === name);
        const actualStock = invItem ? invItem.stock : 0;
        return { name, Vendidos: productMap[name], Stock: actualStock };
     })
     .sort((a,b) => b.Vendidos - a.Vendidos)
     .slice(0, 15);

  // Renderizadores personalizados
  const CustomTooltip = ({ active, payload, label }) => {
    if (active && payload && payload.length) {
      return (
        <div className="bg-[#161b22] border border-slate-700 p-3 rounded-lg shadow-xl">
          <p className="text-white font-semibold">{label || payload[0]?.name}</p>
          {payload.map((entry, index) => (
             <p key={index} style={{ color: entry.color }} className="font-bold text-sm mt-1">
                {entry.name}: {entry.value}
             </p>
          ))}
        </div>
      );
    }
    return null;
  };

  return (
    <div className="flex-1 p-8 overflow-y-auto">
      <div className="max-w-7xl mx-auto space-y-6">
        
        {/* Header */}
        <div className="flex justify-between items-center bg-[#161b22] p-6 rounded-3xl border border-slate-800/60 shadow-lg mb-8">
           <div>
              <h1 className="text-3xl font-bold text-white tracking-tight flex items-center gap-3">
                 <TrendingUp className="text-indigo-500 w-8 h-8" /> 
                 Analíticas y Rendimiento
              </h1>
              <p className="text-slate-400 mt-2">Visión general del desempeño financiero de Susy Market</p>
           </div>
           
           <div className="flex gap-4">
              <div className="bg-[#0f141a] border border-slate-800 p-4 rounded-xl text-right min-w-[150px]">
                 <p className="text-slate-400 text-xs font-semibold uppercase tracking-wider">Ingreso Neto Mágico</p>
                 <p className="text-2xl font-bold text-emerald-400">${totalRevenue.toFixed(2)}</p>
              </div>
              <div className="bg-[#0f141a] border border-slate-800 p-4 rounded-xl text-right min-w-[150px]">
                 <p className="text-slate-400 text-xs font-semibold uppercase tracking-wider">Cobros Pendientes</p>
                 <p className="text-2xl font-bold text-orange-400">${totalDebt.toFixed(2)}</p>
              </div>
           </div>
        </div>

        {/* Charts Row 1 */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
           {/* Grafico de Distribución de Pagos */}
           <div className="bg-[#161b22] border border-slate-800 p-6 rounded-2xl shadow-lg flex flex-col items-center">
              <h3 className="text-lg font-semibold text-white mb-6 flex items-center gap-2 self-start w-full border-b border-slate-800 pb-4">
                <PieChartIcon className="w-5 h-5 text-indigo-400" />
                Distribución de Pagos
              </h3>
              {paymentData.length === 0 ? (
                 <p className="text-slate-500 m-auto py-10">No hay ventas registradas</p>
              ) : (
                 <div className="w-full h-[300px]">
                    <ResponsiveContainer width="100%" height="100%">
                      <PieChart>
                        <Pie data={paymentData} cx="50%" cy="50%" innerRadius={70} outerRadius={110} paddingAngle={5} dataKey="value">
                          {paymentData.map((entry, index) => (
                            <Cell key={`cell-${index}`} fill={entry.color} stroke="transparent" />
                          ))}
                        </Pie>
                        <RechartsTooltip content={<CustomTooltip />} />
                        <Legend verticalAlign="bottom" height={36}/>
                      </PieChart>
                    </ResponsiveContainer>
                 </div>
              )}
           </div>

           {/* Gráfico Temporal L7D */}
           <div className="bg-[#161b22] border border-slate-800 p-6 rounded-2xl shadow-lg">
              <h3 className="text-lg font-semibold text-white mb-6 flex items-center gap-2 border-b border-slate-800 pb-4">
                <BarChart3 className="w-5 h-5 text-emerald-400" />
                Ingresos Últimos 7 Días
              </h3>
              <div className="w-full h-[300px]">
                 <ResponsiveContainer width="100%" height="100%">
                   <BarChart data={timeData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                     <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" vertical={false} />
                     <XAxis dataKey="fecha" stroke="#64748b" tick={{ fill: '#64748b', fontSize: 12 }} axisLine={false} tickLine={false} />
                     <YAxis stroke="#64748b" tick={{ fill: '#64748b', fontSize: 12 }} axisLine={false} tickLine={false} />
                     <RechartsTooltip cursor={{fill: '#1e293b'}} content={<CustomTooltip />} />
                     <Bar dataKey="Ingresos" fill="#10b981" radius={[6, 6, 0, 0]} />
                   </BarChart>
                 </ResponsiveContainer>
              </div>
           </div>
        </div>

        {/* Charts Row 2 */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mt-6">
           <div className="bg-[#161b22] border border-slate-800 p-6 rounded-2xl shadow-lg">
              <h3 className="text-lg font-semibold text-white mb-6 flex items-center gap-2 border-b border-slate-800 pb-4">
                 <DollarSign className="w-5 h-5 text-indigo-400" />
                 Ranking de Ventas por Empleado
              </h3>
              <div className="w-full h-[300px]">
                 <ResponsiveContainer width="100%" height="100%">
                   <BarChart data={employeeData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                     <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" vertical={false} />
                     <XAxis dataKey="name" stroke="#64748b" tick={{ fill: '#64748b', fontSize: 13 }} axisLine={false} tickLine={false} />
                     <YAxis stroke="#64748b" tick={{ fill: '#64748b', fontSize: 12 }} axisLine={false} tickLine={false} />
                     <RechartsTooltip cursor={{fill: '#1e293b'}} content={<CustomTooltip />} />
                     <Bar dataKey="Ventas" fill="#6366f1" radius={[6, 6, 0, 0]} barSize={50} />
                   </BarChart>
                 </ResponsiveContainer>
              </div>
           </div>

           <div className="bg-[#161b22] border border-slate-800 p-6 rounded-2xl shadow-lg">
              <h3 className="text-lg font-semibold text-white mb-6 flex items-center gap-2 border-b border-slate-800 pb-4">
                 <TrendingUp className="w-5 h-5 text-amber-400" />
                 Top 15 Productos vendidas vs Stock
              </h3>
              <div className="w-full h-[500px]">
                 <ResponsiveContainer width="100%" height="100%">
                   <BarChart data={productData} layout="vertical" margin={{ top: 10, right: 10, left: 10, bottom: 0 }}>
                     <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" horizontal={false} />
                     <XAxis type="number" stroke="#64748b" tick={{ fill: '#64748b', fontSize: 12 }} axisLine={false} tickLine={false} />
                     <YAxis type="category" dataKey="name" stroke="#64748b" tick={{ fill: '#ebf8ff', fontSize: 11 }} width={120} axisLine={false} tickLine={false} />
                     <RechartsTooltip cursor={{fill: '#1e293b'}} content={<CustomTooltip />} />
                     <Legend verticalAlign="top" height={36}/>
                     <Bar dataKey="Vendidos" fill="#f59e0b" radius={[0, 6, 6, 0]} barSize={12} />
                     <Bar dataKey="Stock" fill="#94a3b8" radius={[0, 6, 6, 0]} barSize={12} />
                   </BarChart>
                 </ResponsiveContainer>
              </div>
           </div>
        </div>

      </div>
    </div>
  );
}

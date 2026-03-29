import { useState, useEffect } from 'react';
import { Store, KeyRound, ShoppingCart, Package, Users, LogOut, TrendingUp, AlertCircle, ArrowUpRight } from 'lucide-react';
import KeysManager from '../components/KeysManager';
import ProductsManager from '../components/ProductsManager';
import SalesManager from '../components/SalesManager';
import ClientsManager from '../components/ClientsManager';
import HouseLogo3D from '../components/HouseLogo3D';
import { supabase } from '../lib/supabaseClient';

export default function Dashboard({ store }) {
  const [activeTab, setActiveTab] = useState('keys');
  const [globalSales, setGlobalSales] = useState([]);
  
  const fetchGlobalSales = async () => {
     const { data, error } = await supabase.from('sales').select('amount, is_debt, is_voided').eq('store_id', store.id);
     if (error) {
        console.error('Error fetching global sales:', error);
        alert('Error: Faltan columnas en Supabase (is_debt, is_voided, customer_name, etc). Ejecuta el SQL necesario.');
     }
     if(data) setGlobalSales(data);
  };

  useEffect(() => {
     if(store) fetchGlobalSales();
  }, [store]);

  const totalRevenue = globalSales.filter(s => !s.is_debt && !s.is_voided).reduce((acc, sale) => acc + Number(sale.amount), 0);
  const totalDebt = globalSales.filter(s => s.is_debt && !s.is_voided).reduce((acc, sale) => acc + Number(sale.amount), 0);

  return (
    <div className="min-h-screen bg-[#0d1117] text-slate-200 font-sans selection:bg-indigo-500/30">
      <div className="flex h-screen overflow-hidden">
        
        {/* Sidebar */}
        <aside className="w-72 bg-[#161b22] border-r border-slate-800 flex flex-col z-20 shadow-2xl">
          <div className="p-6 pb-2 text-2xl font-extrabold flex items-center gap-3 tracking-tight text-white mb-2">
            <div className="w-12 h-12 flex items-center justify-center">
              <HouseLogo3D width={50} height={50} />
            </div>
            Susy Market
          </div>
          <div className="px-6 pb-6 border-b border-slate-800/50 mb-4">
             <span className="text-xs font-semibold text-indigo-400 uppercase tracking-wider block">TIENDA ACTIVA</span>
             <span className="text-white/90 truncate block text-lg font-medium">{store.name}</span>
          </div>

          <nav className="flex-1 px-4 space-y-2">
            <NavItem active={activeTab === 'keys'} onClick={() => setActiveTab('keys')} icon={<KeyRound size={20} />} label="Llaves de Acceso" />
            <NavItem active={activeTab === 'sales'} onClick={() => setActiveTab('sales')} icon={<ShoppingCart size={20} />} label="Registro de Ventas" />
            <NavItem active={activeTab === 'products'} onClick={() => setActiveTab('products')} icon={<Package size={20} />} label="Catálogo" />
            <NavItem active={activeTab === 'clients'} onClick={() => setActiveTab('clients')} icon={<Users size={20} />} label="Clientes y Fiados" />
          </nav>

          <div className="p-4 border-t border-slate-800/50">
             <button onClick={() => supabase.auth.signOut()} className="w-full flex items-center gap-4 px-4 py-3 rounded-xl transition-all duration-200 text-slate-400 hover:bg-rose-500/10 hover:text-rose-400">
               <LogOut size={20} />
               Cerrar Sesión
             </button>
          </div>
        </aside>

        {/* Main Content */}
        <main className="flex-1 overflow-y-auto relative bg-[#0b0f14] p-8">
          <div className="absolute top-0 left-0 w-full h-96 bg-gradient-to-b from-indigo-500/5 to-transparent pointer-events-none"></div>
          
          <div className="max-w-6xl mx-auto relative z-10 flex flex-col gap-8">
            
            {/* Top KPI Dashboards */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6 animate-in fade-in slide-in-from-top-4">
               <div className="bg-[#161b22] border border-slate-800 p-6 rounded-3xl shadow-xl flex items-center justify-between group hover:border-emerald-500/30 transition-colors">
                  <div>
                    <h3 className="text-slate-400 text-sm font-bold uppercase tracking-widest mb-1 flex items-center gap-2">
                      <TrendingUp className="w-4 h-4 text-emerald-400"/> Beneficios Totales
                    </h3>
                    <p className="text-4xl font-extrabold text-white flex items-baseline gap-2">
                      <span className="text-emerald-400">$</span>{totalRevenue.toFixed(2)}
                    </p>
                  </div>
                  <div className="w-16 h-16 bg-emerald-500/10 rounded-2xl flex items-center justify-center text-emerald-400 group-hover:bg-emerald-500 group-hover:text-white transition-all shadow-inner">
                    <ArrowUpRight className="w-8 h-8"/>
                  </div>
               </div>

               <div className="bg-orange-900/10 border border-orange-500/20 p-6 rounded-3xl shadow-xl flex items-center justify-between group hover:border-orange-500/50 transition-colors relative overflow-hidden">
                  <div className="absolute top-0 right-0 w-32 h-32 bg-orange-500/20 rounded-full blur-3xl -mr-10 -mt-10"></div>
                  <div className="relative z-10">
                    <h3 className="text-orange-400 text-sm font-bold uppercase tracking-widest mb-1 flex items-center gap-2">
                      <AlertCircle className="w-4 h-4 text-orange-400"/> Fiados por Cobrar (Deuda)
                    </h3>
                    <p className="text-4xl font-extrabold text-orange-500 flex items-baseline gap-2">
                      <span className="text-orange-400/50">$</span>{totalDebt.toFixed(2)}
                    </p>
                  </div>
               </div>
            </div>

            {/* Render de Pestañas */}
            <div className="pb-10">
              {activeTab === 'keys' && <KeysManager storeId={store.id} onDashboardUpdate={fetchGlobalSales} />}
              {activeTab === 'sales' && <SalesManager storeId={store.id} />}
              {activeTab === 'products' && <ProductsManager storeId={store.id} />}
              {activeTab === 'clients' && <ClientsManager storeId={store.id} onDashboardUpdate={fetchGlobalSales} />}
            </div>
          </div>
        </main>
      </div>
    </div>
  );
}

function NavItem({ active, icon, label, onClick }) {
  return (
    <button onClick={onClick} className={`w-full flex items-center gap-4 px-4 py-3 rounded-xl transition-all duration-200 ${ active ? 'bg-indigo-500/10 text-indigo-400 font-medium shadow-sm' : 'text-slate-400 hover:bg-white/5 hover:text-slate-200' }`}>
      {icon}
      {label}
    </button>
  );
}

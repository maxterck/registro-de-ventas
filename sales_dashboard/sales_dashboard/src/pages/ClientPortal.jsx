import { useState } from 'react';
import { supabase } from '../lib/supabaseClient';
import { Loader2, AlertCircle, TrendingUp, Key, LogOut } from 'lucide-react';

export default function ClientPortal() {
  const [token, setToken] = useState('');
  const [client, setClient] = useState(null);
  const [loading, setLoading] = useState(false);
  const [errorStr, setErrorStr] = useState('');

  const [sales, setSales] = useState([]);
  const [debt, setDebt] = useState(0);
  const [alerting, setAlerting] = useState(false);

  const loginClient = async (e) => {
    e.preventDefault();
    setLoading(true);
    setErrorStr('');

    const { data, error } = await supabase.from('clients').select('*').eq('token', token.toUpperCase().trim()).maybeSingle();
    
    if (error || !data) {
       setErrorStr('Token inválido. Solicítelo en el mostrador.');
       setLoading(false);
       return;
    }

    setClient(data);
    await fetchSales(data);
    setLoading(false);
  };

  const fetchSales = async (clientData) => {
     const { data } = await supabase.from('sales').select('*').in('customer_name', clientData.alias_names).order('timestamp', { ascending: false });
     if (data) {
        setSales(data);
        setDebt(data.filter(s => s.is_debt).reduce((acc, s) => acc + Number(s.amount), 0));
     }
  };

  const notifyPayment = async () => {
     setAlerting(true);
     await supabase.from('clients').update({ payment_alert: true }).eq('id', client.id);
     setClient({ ...client, payment_alert: true });
     setAlerting(false);
     alert('¡Aviso enviado exitosamente! Acercate a la caja para realizar tu pago.');
  };

  if (!client) {
     return (
        <div className="min-h-screen bg-[#0d1117] flex items-center justify-center p-4">
          <form onSubmit={loginClient} className="max-w-md w-full bg-[#161b22] border border-slate-800 rounded-3xl p-8 shadow-2xl relative overflow-hidden">
             <div className="absolute top-0 right-0 w-32 h-32 bg-orange-500/10 rounded-full blur-2xl -mr-10 -mt-10"></div>
             <div className="flex justify-center mb-6 relative z-10">
                <div className="w-16 h-16 bg-orange-500/10 rounded-full flex items-center justify-center text-orange-400">
                   <Key className="w-8 h-8" />
                </div>
             </div>
             <h2 className="text-2xl font-bold text-white mb-2 text-center relative z-10">Portal para Clientes</h2>
             <p className="text-slate-400 mb-8 text-sm text-center relative z-10">Consulta cuánto es tu cuenta mensual que sacaste fiado en la tienda.</p>
             
             {errorStr && <p className="text-rose-400 bg-rose-500/10 p-3 rounded-lg text-sm mb-4 text-center font-bold">{errorStr}</p>}

             <input type="text" placeholder="TU TOKEN (Ej. FAM-VX12)" value={token} onChange={e => setToken(e.target.value)} required className="w-full bg-[#0b0f14] border border-slate-700 text-white px-5 py-4 rounded-xl mb-6 focus:ring-2 focus:ring-orange-500/50 outline-none text-center font-mono text-xl uppercase tracking-widest relative z-10" />
             <button type="submit" disabled={loading} className="w-full bg-orange-600 hover:bg-orange-500 text-white px-8 py-4 rounded-xl font-bold transition-all shadow-lg flex justify-center text-lg relative z-10">
                {loading ? <Loader2 className="w-6 h-6 animate-spin"/> : 'Ingresar'}
             </button>
          </form>
        </div>
     );
  }

  return (
     <div className="min-h-screen bg-[#0d1117] text-white selection:bg-orange-500/30">
        <header className="bg-[#161b22] border-b border-slate-800 p-6 flex justify-between items-center sticky top-0 z-20 shadow-2xl">
           <div>
              <h1 className="text-xl font-bold text-slate-200">Mis Fiados</h1>
              <p className="text-sm text-slate-500 mt-1">Token Familia: <span className="text-orange-400 font-mono tracking-widest">{client.token}</span></p>
           </div>
           <button onClick={() => setClient(null)} className="flex items-center gap-2 text-slate-400 hover:text-rose-400 transition-colors bg-[#0b0f14] px-4 py-2 border border-slate-800 rounded-xl">
              <LogOut className="w-4 h-4" /> Salir
           </button>
        </header>

        <main className="max-w-3xl mx-auto p-4 md:p-8 space-y-8">
           <div className={`border rounded-3xl p-8 text-center relative overflow-hidden transition-all duration-500 ${debt > 0 ? 'bg-orange-900/10 border-orange-500/30 shadow-[0_0_40px_-15px_rgba(249,115,22,0.3)]' : 'bg-emerald-900/10 border-emerald-500/30'}`}>
              <div className={`absolute top-0 right-0 w-64 h-64 rounded-full blur-3xl -mr-20 -mt-20 opacity-50 ${debt > 0 ? 'bg-orange-500/20' : 'bg-emerald-500/20'}`}></div>
              
              <h2 className={`text-sm font-bold uppercase tracking-widest mb-4 opacity-80 ${debt > 0 ? 'text-orange-400' : 'text-emerald-400'}`}>
                 Tu Deuda Actual
              </h2>
              <p className={`text-6xl md:text-7xl font-black mb-8 tracking-tighter ${debt > 0 ? 'text-orange-500' : 'text-emerald-500'}`}>
                 ${debt.toFixed(2)}
              </p>

              {debt > 0 && (
                 <button 
                    onClick={notifyPayment}
                    disabled={alerting || client.payment_alert}
                    className={`w-full md:w-auto px-8 py-4 rounded-xl font-black text-lg shadow-xl uppercase tracking-wider mx-auto flex justify-center items-center gap-2 transition-all active:scale-95 ${
                       client.payment_alert 
                         ? 'bg-orange-900 text-orange-400 opacity-50 cursor-not-allowed' 
                         : 'bg-orange-500 text-white hover:bg-orange-400 shadow-orange-500/20 hover:shadow-orange-500/40'
                    }`}
                 >
                    {alerting ? <Loader2 className="w-6 h-6 animate-spin"/> : client.payment_alert ? '✅ Aviso Enviado' : 'Avisar que quiero pagar'}
                 </button>
              )}
           </div>

           <div>
              <h3 className="text-xl font-bold mb-4 flex items-center gap-2 text-slate-300">
                 <AlertCircle className="text-orange-500 w-5 h-5"/> Detalle de compras a fiado
              </h3>
              
              <div className="bg-[#161b22] border border-slate-800 rounded-3xl overflow-hidden divide-y divide-slate-800/60 shadow-xl">
                 {sales.filter(s => s.is_debt).length === 0 ? (
                    <div className="p-8 text-center text-slate-500 font-medium">No tienes deudas activas actualmente. ¡Todo al día!</div>
                 ) : (
                    sales.filter(s => s.is_debt).map(sale => (
                       <div key={sale.id} className="p-4 md:p-6 flex justify-between items-center group hover:bg-white/5 transition-colors">
                          <div className="flex flex-col">
                             <span className="text-white font-semibold text-lg">{sale.product_description}</span>
                             <span className="text-slate-500 text-sm mt-1">{new Date(sale.timestamp).toLocaleString()} • P. {sale.customer_name}</span>
                          </div>
                          <span className="text-orange-400 font-black text-xl whitespace-nowrap">
                             ${Number(sale.amount).toFixed(2)}
                          </span>
                       </div>
                    ))
                 )}
              </div>
           </div>

           <div className="opacity-60 pt-8">
              <h3 className="text-lg font-bold mb-4 flex items-center gap-2 text-slate-400">
                 <TrendingUp className="text-slate-500 w-5 h-5"/> Historial de Pagos Anteriores
              </h3>
              <div className="bg-[#161b22]/50 border border-slate-800/50 rounded-3xl overflow-hidden divide-y divide-slate-800/30">
                 {sales.filter(s => !s.is_debt).length === 0 ? (
                    <div className="p-6 text-center text-slate-600">Sin historial de pagos registrados a tu código.</div>
                 ) : (
                    sales.filter(s => !s.is_debt).slice(0, 5).map(sale => (
                       <div key={sale.id} className="p-4 flex justify-between items-center">
                          <div className="flex flex-col">
                             <span className="text-slate-300 font-medium">{sale.product_description} <span className="text-slate-600 text-xs ml-2">(Saldado)</span></span>
                             <span className="text-slate-600 text-xs mt-1">{new Date(sale.timestamp).toLocaleDateString()}</span>
                          </div>
                          <span className="text-emerald-500/70 font-black">
                             ${Number(sale.amount).toFixed(2)}
                          </span>
                       </div>
                    ))
                 )}
              </div>
           </div>
        </main>
     </div>
  );
}

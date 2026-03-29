import { useState, useEffect } from 'react';
import { supabase } from './lib/supabaseClient';
import Dashboard from './pages/Dashboard';
import ClientPortal from './pages/ClientPortal';
import Auth from './components/Auth';
import { Loader2, Store } from 'lucide-react';

export default function App() {
  const [session, setSession] = useState(null);
  const [store, setStore] = useState(null);
  const [loading, setLoading] = useState(true);
  const [storeName, setStoreName] = useState('');

  // Routing casero para no instalar react-router
  const isClientPortal = window.location.pathname.startsWith('/client');

  useEffect(() => {
    if (isClientPortal) {
       setLoading(false); // No necesitamos auth del admin
       return;
    }

    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      if (session) checkStore(session.user.id);
      else setLoading(false);
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session);
      if (session) checkStore(session.user.id);
      else setStore(null);
    });

    return () => subscription.unsubscribe();
  }, []);

  const checkStore = async (userId) => {
    setLoading(true);
    const { data } = await supabase.from('stores').select('*').eq('owner_id', userId).maybeSingle();
    setStore(data);
    setLoading(false);
  };

  const createStore = async (e) => {
    e.preventDefault();
    setLoading(true);
    const { data, error } = await supabase.from('stores').insert([{ owner_id: session.user.id, name: storeName }]).select().single();
    if (!error && data) setStore(data);
    else alert(error?.message || 'Error al crear la tienda');
    setLoading(false);
  };

  if (loading) return <div className="min-h-screen bg-[#0d1117] flex items-center justify-center text-white"><Loader2 className="w-10 h-10 animate-spin text-indigo-500"/></div>;

  if (isClientPortal) return <ClientPortal />;

  if (!session) return <Auth onLogin={() => {}} />;

  if (!store) {
    return (
      <div className="min-h-screen bg-[#0d1117] flex items-center justify-center p-4">
        <form onSubmit={createStore} className="max-w-md w-full bg-[#161b22] border border-slate-800 rounded-3xl p-8 shadow-2xl">
          <div className="flex justify-center mb-6">
             <Store className="text-indigo-400 w-12 h-12" />
          </div>
          <h2 className="text-2xl font-bold text-white mb-2 text-center">Configura tu Negocio</h2>
          <p className="text-slate-400 mb-8 text-sm text-center">Para poder asignar llaves y vender, primero ponle un nombre a tu tienda.</p>
          <input type="text" placeholder="Nombre (Ej. Kiosko Los Pinos)" value={storeName} onChange={e => setStoreName(e.target.value)} required className="w-full bg-[#0b0f14] border border-slate-700 text-white px-5 py-3.5 rounded-xl mb-6 focus:ring-2 focus:ring-indigo-500/50 focus:outline-none placeholder:text-slate-600" />
          <button type="submit" disabled={loading} className="w-full bg-indigo-600 hover:bg-indigo-500 text-white px-8 py-3.5 rounded-xl font-semibold transition-all shadow-lg flex justify-center">{loading ? <Loader2 className="w-5 h-5 animate-spin"/> : 'Comenzar a usar SalesSync'}</button>
        </form>
      </div>
    );
  }

  return <Dashboard store={store} />;
}

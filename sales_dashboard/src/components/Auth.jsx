import { useState } from 'react';
import { supabase } from '../lib/supabaseClient';
import { Store, ArrowRight, Loader2 } from 'lucide-react';

export default function Auth({ onLogin }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isLogin, setIsLogin] = useState(true);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const handleAuth = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      if (isLogin) {
        const { error } = await supabase.auth.signInWithPassword({ email, password });
        if (error) throw error;
      } else {
        const { error } = await supabase.auth.signUp({ email, password });
        if (error) throw error;
        alert('Registro exitoso. Revisa tu email o inicia sesión si el auto-login funcionó.');
      }
      onLogin();
    } catch (err) {
      setError(err.message === 'Invalid login credentials' ? 'Credenciales inválidas' : err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#0d1117] flex items-center justify-center p-4">
      <div className="max-w-md w-full bg-[#161b22] border border-slate-800 rounded-3xl p-8 shadow-2xl relative overflow-hidden">
        <div className="absolute top-0 right-0 w-64 h-64 bg-indigo-500/5 rounded-full blur-3xl -mr-10 -mt-20"></div>
        <div className="flex justify-center mb-8 relative z-10">
           <div className="w-16 h-16 rounded-2xl bg-gradient-to-tr from-indigo-500 to-purple-500 flex items-center justify-center shadow-lg shadow-indigo-500/20">
              <Store className="text-white w-8 h-8" />
           </div>
        </div>
        <h2 className="text-2xl font-bold text-white text-center mb-6 relative z-10">
          {isLogin ? 'Ingresar como Dueño' : 'Crear Cuenta de Dueño'}
        </h2>
        {error && <div className="bg-red-500/10 border border-red-500/50 text-red-500 p-3 rounded-lg mb-4 text-sm relative z-10">{error}</div>}
        <form onSubmit={handleAuth} className="space-y-4 relative z-10">
          <div>
             <input type="email" placeholder="Correo Electrónico" required value={email} onChange={e => setEmail(e.target.value)} className="w-full bg-[#0b0f14] border border-slate-700 text-white px-5 py-3.5 rounded-xl focus:outline-none focus:ring-2 focus:ring-indigo-500/50" />
          </div>
          <div>
             <input type="password" placeholder="Contraseña (mínimo 6 caracteres)" required minLength={6} value={password} onChange={e => setPassword(e.target.value)} className="w-full bg-[#0b0f14] border border-slate-700 text-white px-5 py-3.5 rounded-xl focus:outline-none focus:ring-2 focus:ring-indigo-500/50" />
          </div>
          <button disabled={loading} type="submit" className="w-full bg-indigo-600 hover:bg-indigo-500 text-white px-8 py-3.5 rounded-xl font-semibold transition-all shadow-lg shadow-indigo-500/25 flex items-center justify-center gap-2">
            {loading ? <Loader2 className="w-5 h-5 animate-spin"/> : (isLogin ? 'Iniciar Sesión' : 'Registrar Negocio')}
            {!loading && <ArrowRight className="w-5 h-5" />}
          </button>
        </form>
        <div className="mt-6 text-center relative z-10">
          <button onClick={() => setIsLogin(!isLogin)} className="text-slate-400 hover:text-white transition-colors text-sm">
            {isLogin ? '¿No tienes cuenta? Regístrate aquí' : '¿Ya tienes cuenta? Ingresa aquí'}
          </button>
        </div>
      </div>
    </div>
  );
}

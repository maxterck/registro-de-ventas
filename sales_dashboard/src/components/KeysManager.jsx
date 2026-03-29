import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabaseClient';
import { Key, UserPlus, ShieldAlert, MonitorCheck, Loader2, Trash2, Receipt, TrendingUp, Power, PowerOff, X, FileText, Scale } from 'lucide-react';
import { toast } from 'sonner';

export default function KeysManager({ storeId }) {
  const [keys, setKeys] = useState([]);
  const [newEmployeeName, setNewEmployeeName] = useState('');
  const [newRole, setNewRole] = useState('edit');
  const [loading, setLoading] = useState(true);

  // Estado para el Modal de Historial Individual
  const [selectedEmployeeSales, setSelectedEmployeeSales] = useState(null);
  const [modalLoading, setModalLoading] = useState(false);

  useEffect(() => {
    if (storeId) loadKeys();
  }, [storeId]);

  const loadKeys = async () => {
    setLoading(true);
    // Join con ventas para obtener las estadísticas rápidas!
    const { data } = await supabase
       .from('access_keys')
       .select('*, sales(amount)')
       .eq('store_id', storeId)
       .order('created_at', { ascending: false });
       
    if (data) setKeys(data);
    setLoading(false);
  };

  const generateAccessKey = async (e) => {
    e.preventDefault();
    if (!newEmployeeName) return;
    setLoading(true);
    const randomToken = "POS-" + Math.random().toString(36).substring(2, 7).toUpperCase();
    
    const { data, error } = await supabase.from('access_keys').insert([{
      store_id: storeId,
      key_token: randomToken,
      employee_name: newEmployeeName,
      role: newRole,
      is_active: true
    }]).select('*, sales(amount)').single();
    
    if (error) toast.error(error.message);
    if (data) {
      setKeys([data, ...keys]);
      setNewEmployeeName('');
    }
    setLoading(false);
  };

  const toggleStatus = async (keyData) => {
    const { data } = await supabase.from('access_keys').update({ is_active: !keyData.is_active }).eq('id', keyData.id).select('*, sales(amount)').single();
    if (data) {
      setKeys(keys.map(k => k.id === keyData.id ? data : k));
    }
  };

  const deleteKey = async (id) => {
    if(confirm('¿Seguro que deseas eliminar a este empleado permanentemente?')) {
       await supabase.from('access_keys').delete().eq('id', id);
       setKeys(keys.filter(k => k.id !== id));
    }
  };

  const toggleVIP = async (keyData) => {
    const newVal = !keyData.can_manage_products;
    const { data, error } = await supabase.from('access_keys').update({ can_manage_products: newVal }).eq('id', keyData.id).select('*, sales(amount)').single();
    if (data) {
      setKeys(keys.map(k => k.id === keyData.id ? data : k));
      if (newVal) toast.success('🌟 Función VIP Activada: Este empleado ahora puede añadir/modificar productos.');
      else toast.info('Permisos VIP desactivados.');
    } else {
      toast.error('Error: Asegúrate de haber ejecutado el SQL para añadir la columna can_manage_products');
    }
  };

  const toggleDebtPerm = async (keyData) => {
    const newVal = !keyData.can_settle_debts;
    const { data, error } = await supabase.from('access_keys').update({ can_settle_debts: newVal }).eq('id', keyData.id).select('*, sales(amount)').single();
    if (data) {
      setKeys(keys.map(k => k.id === keyData.id ? data : k));
      if (newVal) toast.success('⚖️ Permiso Otorgado: Este cajero ahora puede saldar deudas de Fiados.');
    } else {
      toast.error('Error: Asegúrate de haber ejecutado el SQL para añadir la columna can_settle_debts (ALTER TABLE access_keys ADD COLUMN can_settle_debts BOOLEAN DEFAULT false;)');
    }
  };

  const toggleShiftControl = async (keyData) => {
    const newVal = !keyData.requires_shift_control;
    const { data, error } = await supabase.from('access_keys').update({ requires_shift_control: newVal }).eq('id', keyData.id).select('*, sales(amount)').single();
    if (data) {
      setKeys(keys.map(k => k.id === keyData.id ? data : k));
      if (newVal) toast.success('🔒 Control de Caja Activado. Se le exigirá a este cajero declarar dinero inicial.');
      else toast.info('Control de Caja Desactivado.');
    } else {
      toast.error('Error al actualizar el control de caja.');
    }
  };

  // Cargar el detalle individual para el Modal
  const openEmployeeHistory = async (keyId, employeeName) => {
    setModalLoading(true);
    setSelectedEmployeeSales({ name: employeeName, sales: [] });
    const { data } = await supabase
      .from('sales')
      .select('*')
      .eq('created_by_key', keyId)
      .order('timestamp', { ascending: false });
    
    if (data) {
       setSelectedEmployeeSales({ name: employeeName, sales: data });
    }
    setModalLoading(false);
  };

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500 relative">
      <div className="flex items-center justify-between">
         <h1 className="text-3xl font-bold tracking-tight text-white flex items-center gap-3">
            <UserPlus className="w-8 h-8 text-indigo-400" />
            Equipo y Cajas
         </h1>
      </div>
      
      <p className="text-slate-400 max-w-2xl text-lg">
        Crea accesos para tu equipo y supervisa el rendimiento y el registro exacto de cada cajero. Toca Ver Historial en su tarjeta para auditarlo.
      </p>

      {/* Tarjeta de Generación de Empleados */}
      <div className="bg-[#161b22]/80 border border-slate-800 rounded-3xl p-6 lg:p-8 shadow-2xl relative overflow-hidden backdrop-blur-md">
        <div className="absolute top-0 right-0 w-64 h-64 bg-indigo-500/10 rounded-full blur-3xl -mr-10 -mt-20"></div>
        <h2 className="text-lg font-medium text-white mb-6 flex items-center gap-2 relative z-10">
           Añadir Nuevo Empleado o Caja
        </h2>
        
        <form onSubmit={generateAccessKey} className="flex flex-col md:flex-row gap-4 relative z-10">
          <input 
            type="text" 
            placeholder="Nombre (Ej. Juan Perez o Caja Frontal)" 
            value={newEmployeeName}
            onChange={(e) => setNewEmployeeName(e.target.value)}
            className="flex-1 bg-[#0b0f14] border border-slate-700 text-white px-5 py-3.5 rounded-xl focus:outline-none focus:ring-2 focus:ring-indigo-500/50 transition-all font-medium"
            required
            disabled={loading}
          />
          <select 
            value={newRole} 
            onChange={(e) => setNewRole(e.target.value)}
            disabled={loading}
            className="bg-[#0b0f14] border border-slate-700 text-white px-5 py-3.5 rounded-xl focus:outline-none focus:ring-2 focus:ring-indigo-500/50 transition-all cursor-pointer font-medium"
          >
            <option value="edit">Cajero Autorizado (Vender)</option>
            <option value="read_only">Junior (Solo Ver Inventario)</option>
          </select>
          <button 
            type="submit" 
            disabled={loading}
            className="bg-indigo-600 hover:bg-indigo-500 text-white px-8 py-3.5 rounded-xl font-semibold transition-all shadow-lg shadow-indigo-500/25 active:scale-95 flex items-center justify-center gap-2"
          >
            {loading ? <Loader2 className="w-5 h-5 animate-spin"/> : 'Generar Acceso'}
          </button>
        </form>
      </div>

      {loading && keys.length === 0 && (
         <div className="flex justify-center p-12"><Loader2 className="w-10 h-10 text-indigo-500 animate-spin"/></div>
      )}

      {/* Grid de Cartas de Empleados */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {keys.map((key) => {
           const activeSales = key.sales ? key.sales.filter(s => !s.is_voided) : [];
           const totalSales = activeSales.length;
           const totalRevenue = activeSales.reduce((sum, s) => sum + Number(s.amount), 0);

           return (
             <div key={key.id} className={`flex flex-col bg-[#161b22] border rounded-3xl p-6 shadow-xl transition-all duration-300 relative overflow-hidden group ${key.is_active ? 'border-slate-800 hover:border-indigo-500/40' : 'border-rose-900/50 opacity-80'}`}>
                {/* Indicador visual de desactivado */}
                {!key.is_active && <div className="absolute inset-0 bg-black/40 z-0 pointer-events-none"></div>}
                
                <div className="flex items-start justify-between relative z-10 mb-6">
                   <div className="flex items-center gap-4">
                      <div className={`w-14 h-14 rounded-2xl flex items-center justify-center shadow-inner ${key.is_active ? 'bg-gradient-to-tr from-indigo-500/20 to-purple-500/20 text-indigo-400' : 'bg-rose-500/10 text-rose-400'}`}>
                         <MonitorCheck className="w-7 h-7" />
                      </div>
                      <div>
                         <h3 className="text-white font-bold text-xl drop-shadow-sm">{key.employee_name}</h3>
                          {key.role === 'edit' 
                            ? <span className="text-xs font-semibold text-emerald-400 flex items-center gap-1 mt-1"><ShieldAlert className="w-3.5 h-3.5"/> Cajero Activo {key.can_manage_products && '(VIP)'}</span>
                            : <span className="text-xs font-semibold text-amber-400 flex items-center gap-1 mt-1">Solo Lectura</span>
                         }
                      </div>
                   </div>
                   <div className="flex flex-col gap-2">
                      <button onClick={() => toggleVIP(key)} className={`transition-colors p-2 rounded-xl border ${key.can_manage_products ? 'bg-amber-500/10 text-amber-400 border-amber-500/30 shadow-lg shadow-amber-500/20' : 'text-slate-500 border-transparent hover:bg-slate-800'}`} title="Otorgar Permisos VIP (Gestión Productos)">
                         <MonitorCheck className="w-5 h-5" />
                      </button>
                      <button onClick={() => toggleDebtPerm(key)} className={`transition-colors p-2 rounded-xl border ${key.can_settle_debts ? 'bg-indigo-500/10 text-indigo-400 border-indigo-500/30 shadow-lg shadow-indigo-500/20' : 'text-slate-500 border-transparent hover:bg-slate-800'}`} title="Permitir Saldar Deudas">
                         <Scale className="w-5 h-5" />
                      </button>
                      <button onClick={() => deleteKey(key.id)} className="text-slate-600 hover:text-rose-400 transition-colors p-2 hover:bg-rose-500/10 rounded-xl" title="Eliminar empleado">
                         <Trash2 className="w-5 h-5" />
                      </button>
                   </div>
                </div>
                
                {/* Mini Estadísticas */}
                <div className="grid grid-cols-2 gap-4 py-3 border-t border-slate-800/60 relative z-10 flex-1">
                   <div>
                      <p className="text-slate-500 text-xs font-bold uppercase mb-1.5 flex items-center gap-1.5"><Receipt className="w-3.5 h-3.5"/> Num. Ventas</p>
                      <p className="text-white font-bold text-2xl">{totalSales}</p>
                   </div>
                   <div>
                      <p className="text-slate-500 text-xs font-bold uppercase mb-1.5 flex items-center gap-1.5"><TrendingUp className="w-3.5 h-3.5 text-emerald-400"/> Recaudado</p>
                      <p className="text-emerald-400 font-extrabold text-2xl">${totalRevenue.toFixed(2)}</p>
                   </div>
                </div>

                {/* Botón Ver Historial */}
                <div className="py-2 border-b border-slate-800/60 relative z-10 mb-4">
                   <button 
                     onClick={() => openEmployeeHistory(key.id, key.employee_name)}
                     className="w-full text-indigo-400 font-medium text-sm flex items-center justify-center gap-2 py-2 hover:bg-white/5 rounded-lg transition-colors"
                   >
                     <FileText className="w-4 h-4"/> Ver Historial Individual
                   </button>
                </div>

                {/* Zona de Token y Estado */}
                <div className="relative z-10 flex items-center justify-between gap-3">
                   <div className="flex-1">
                       <p className="text-[10px] text-slate-500 uppercase font-bold tracking-wider mb-1">Clave de Acceso (App)</p>
                       <span className="font-mono bg-[#0b0f14] text-white px-3 py-2 rounded-xl text-lg border border-slate-800 tracking-[0.15em] shadow-inner font-extrabold flex items-center justify-center">
                         {key.key_token}
                       </span>
                   </div>
                   <button 
                     onClick={() => toggleStatus(key)}
                     title={key.is_active ? "Desactivar acceso" : "Activar acceso"}
                     className={`w-14 h-14 rounded-xl flex items-center justify-center transition-all ${
                       key.is_active 
                         ? 'bg-rose-500/10 text-rose-400 border border-rose-500/30 hover:bg-rose-500 hover:text-white' 
                         : 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/30 hover:bg-emerald-500 hover:text-white'
                     }`}
                   >
                     {key.is_active ? <PowerOff className="w-6 h-6" /> : <Power className="w-6 h-6" />}
                   </button>
                </div>
             </div>
           );
        })}
      </div>

      {/* Modal / Overlay del Historial Individual */}
      {selectedEmployeeSales && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-in fade-in">
           <div className="bg-[#161b22] border border-slate-700 w-full max-w-3xl max-h-[85vh] rounded-3xl overflow-hidden shadow-2xl flex flex-col slide-in-from-bottom-8">
              <div className="p-6 border-b border-slate-800 flex justify-between items-center bg-[#0d1117]">
                 <div>
                   <h2 className="text-2xl font-bold text-white flex items-center gap-2">
                     <FileText className="text-indigo-400 w-6 h-6" /> Historial de <span className="text-indigo-300">{selectedEmployeeSales.name}</span>
                   </h2>
                   <p className="text-slate-500 text-sm mt-1">Todas las ventas procesadas y registradas por este usuario.</p>
                 </div>
                 <button onClick={() => setSelectedEmployeeSales(null)} className="p-2 text-slate-400 hover:text-white hover:bg-slate-800 rounded-xl transition-colors">
                    <X className="w-6 h-6"/>
                 </button>
              </div>
              
              <div className="flex-1 overflow-auto p-6 bg-[#0b0f14]">
                 {modalLoading ? (
                    <div className="flex justify-center p-10"><Loader2 className="w-8 h-8 text-indigo-500 animate-spin"/></div>
                 ) : selectedEmployeeSales.sales.length === 0 ? (
                    <div className="text-center p-10 mt-10 text-slate-500 font-medium">Este cajero todavía no ha registrado ninguna venta.</div>
                 ) : (
                    <div className="space-y-4">
                       {selectedEmployeeSales.sales.map((sale) => (
                          <div key={sale.id} className="flex items-center justify-between p-4 bg-[#161b22] border border-slate-800 rounded-2xl hover:border-indigo-500/30 transition-colors">
                             <div className="flex items-center gap-4">
                                <div className="w-10 h-10 bg-emerald-500/10 text-emerald-400 rounded-full flex items-center justify-center">
                                   <Receipt className="w-5 h-5"/>
                                </div>
                                <div>
                                   <p className="text-white font-semibold text-lg">{sale.product_description}</p>
                                   <p className="text-slate-500 text-sm">{new Date(sale.timestamp).toLocaleString()}</p>
                                </div>
                             </div>
                             <div className="text-right">
                                <p className="text-emerald-400 font-bold text-xl">+ ${Number(sale.amount).toFixed(2)}</p>
                                <p className="text-xs font-semibold text-slate-500 uppercase flex justify-end items-center gap-1">
                                   Pagado en Efectivo
                                </p>
                             </div>
                          </div>
                       ))}
                    </div>
                 )}
              </div>
           </div>
        </div>
      )}

    </div>
  );
}

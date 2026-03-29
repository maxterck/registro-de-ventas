import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabaseClient';
import { Clock, ShieldAlert, KeyRound, Loader2, CheckCircle2, RotateCcw } from 'lucide-react';
import { toast } from 'sonner';

export default function ShiftsManager({ storeId }) {
  const [shifts, setShifts] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (storeId) loadShifts();
  }, [storeId]);

  const loadShifts = async () => {
    setLoading(true);
    const { data, error } = await supabase
      .from('shift_records')
      .select('*, access_keys(employee_name)')
      .eq('store_id', storeId)
      .order('opened_at', { ascending: false });

    if (error) {
      toast.error('Error al cargar turnos. ' + error.message);
    } else if (data) {
      setShifts(data);
    }
    setLoading(false);
  };

  const closeShiftForcefully = async (shift) => {
    if (shift.closed_at) return;
    if (!confirm('¿Forzar el cierre de este turno? Al hacerlo, requerirá que el empleado vuelva a ingresar su dinero inicial si quiere volver a operar.')) return;

    const { error } = await supabase
      .from('shift_records')
      .update({ closed_at: new Date().toISOString(), final_cash: 0 })
      .eq('id', shift.id);

    if (error) {
      toast.error('Error cerrando turno: ' + error.message);
    } else {
      toast.success('Turno cerrado forzosamente');
      loadShifts();
    }
  };

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500 relative">
      <div className="flex items-center justify-between">
         <h1 className="text-3xl font-bold tracking-tight text-white flex items-center gap-3">
            <Clock className="w-8 h-8 text-rose-400" />
            Control de Cajas
         </h1>
      </div>
      
      <p className="text-slate-400 max-w-2xl text-lg">
        Aquí puedes monitorear cuánto dinero declararon tus empleados al abrir sus turnos. El "Control Estricto" se activa individualmente en la pestaña "Llaves de Acceso".
      </p>

      {loading && shifts.length === 0 ? (
         <div className="flex justify-center p-12"><Loader2 className="w-10 h-10 text-rose-500 animate-spin"/></div>
      ) : shifts.length === 0 ? (
         <div className="bg-[#161b22] border border-slate-800 p-12 rounded-3xl text-center shadow-xl">
           <ShieldAlert className="w-16 h-16 text-slate-700 mx-auto mb-4" />
           <p className="text-slate-400 text-xl font-bold">Nadie ha inicializado turno aún.</p>
           <p className="text-slate-500 mt-2">Asegúrate de haber prendido el icono violeta de la Caja en "Llaves de Acceso" para que se les exija control.</p>
         </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {shifts.map((shift) => {
             const isOpen = shift.closed_at == null;
             
             return (
               <div key={shift.id} className={`flex flex-col bg-[#161b22] border rounded-3xl overflow-hidden shadow-xl transition-all duration-300 relative group ${isOpen ? 'border-rose-500/50 shadow-rose-500/10 hover:border-rose-400' : 'border-slate-800 hover:border-slate-600'}`}>
                  <div className={`px-5 py-2 flex items-center justify-center font-bold text-xs uppercase tracking-widest ${isOpen ? 'bg-rose-500/20 text-rose-400' : 'bg-slate-800/50 text-slate-400'}`}>
                     {isOpen ? 'TURNO ABIERTO (EN CURSO)' : 'TURNO CERRADO'}
                  </div>
                  
                  <div className="p-6 flex-1 flex flex-col">
                    <div className="flex items-center gap-3 mb-6">
                       <div className="w-10 h-10 rounded-full bg-slate-800 flex items-center justify-center text-slate-300">
                         <KeyRound className="w-5 h-5"/>
                       </div>
                       <div>
                         <p className="text-slate-500 text-xs font-bold uppercase">Cajero Operando</p>
                         <h3 className="text-white font-bold text-xl">{shift.access_keys?.employee_name || 'Desconocido'}</h3>
                       </div>
                    </div>

                    <div className="mb-6 bg-[#0b0f14] border border-slate-800 rounded-2xl p-4 text-center">
                       <p className="text-slate-500 text-xs font-bold uppercase mb-1 flex items-center justify-center gap-2"><Clock className="w-3 h-3"/> Dinero Inicial Declarado</p>
                       <p className="text-rose-400 font-extrabold text-3xl">${Number(shift.opened_cash || 0).toFixed(2)}</p>
                       <p className="text-slate-500 text-[10px] mt-2">Iniciado: {new Date(shift.opened_at).toLocaleString()}</p>
                    </div>

                    {isOpen ? (
                       <button onClick={() => closeShiftForcefully(shift)} className="w-full bg-slate-800 hover:bg-rose-600 hover:text-white text-rose-400 font-semibold py-3 rounded-xl transition-colors flex justify-center items-center gap-2 border border-rose-500/20 hover:border-rose-500">
                          <RotateCcw className="w-4 h-4"/> Forzar Cierre
                       </button>
                    ) : (
                       <div className="w-full bg-emerald-500/10 text-emerald-500 font-semibold py-3 rounded-xl flex justify-center items-center gap-2 border border-emerald-500/20">
                          <CheckCircle2 className="w-4 h-4"/> Finalizado: {new Date(shift.closed_at).toLocaleString()}
                       </div>
                    )}
                  </div>
               </div>
             )
          })}
        </div>
      )}
    </div>
  );
}

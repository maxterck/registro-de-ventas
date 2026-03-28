import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabaseClient';
import { Users, UserPlus, Trash2, Receipt, TrendingUp, DollarSign, WalletCards, ShieldAlert, Loader2, CreditCard, ChevronDown, CheckCircle2, AlertCircle } from 'lucide-react';

export default function ClientsManager({ storeId, onDashboardUpdate }) {
  const [clients, setClients] = useState([]);
  const [loading, setLoading] = useState(true);
  
  // States para crear un cliente
  const [newTokenPrefix, setNewTokenPrefix] = useState('CLI-');
  const [newAlias, setNewAlias] = useState('');
  const [tempAliases, setTempAliases] = useState([]);
  const [isCreating, setIsCreating] = useState(false);

  // States para el Modal de Historial / Gestión de Deuda
  const [selectedClient, setSelectedClient] = useState(null);
  const [clientSales, setClientSales] = useState([]);
  const [modalLoading, setModalLoading] = useState(false);

  useEffect(() => {
    if (storeId) loadClients();
  }, [storeId]);

  const loadClients = async () => {
    setLoading(true);
    // Para no recargar todo, cruzaremos las ventas manualmente o podemos descargar todas las ventas.
    // La forma directa: 
    const { data: clientsData, error: errClients } = await supabase.from('clients').select('*').eq('store_id', storeId).order('created_at', { ascending: false });
    
    // Obtenemos todas las ventas fiadas o de clientes (opcionalmente solo las que tengan is_debt=true para calcular la deuda rapido)
    const { data: salesData } = await supabase.from('sales').select('id, amount, is_debt, payment_method, customer_name, timestamp, is_voided').eq('store_id', storeId);

    if (clientsData && salesData) {
       // Calcular la deuda por cliente cruzando los alias o el mismo Token
       const enrichedClients = clientsData.map(client => {
          const matchedSales = salesData.filter(sale => !sale.is_voided && (client.alias_names.includes(sale.customer_name) || sale.customer_name === client.token));
          const totalDebt = matchedSales.filter(s => s.is_debt).reduce((sum, s) => sum + Number(s.amount), 0);
          const totalPaid = matchedSales.filter(s => !s.is_debt).reduce((sum, s) => sum + Number(s.amount), 0);
          return { ...client, totalDebt, totalPaid, matchedSales };
       });
       setClients(enrichedClients);
    }
    setLoading(false);
  };

  const addAliasToTemp = () => {
    if (newAlias.trim().length > 0 && tempAliases.length < 7 && !tempAliases.includes(newAlias.trim())) {
      setTempAliases([...tempAliases, newAlias.trim()]);
      setNewAlias('');
    }
  };

  const removeAliasFromTemp = (aliasName) => {
    setTempAliases(tempAliases.filter(a => a !== aliasName));
  };

  const createClientToken = async (e) => {
    e.preventDefault();
    if (tempAliases.length === 0) return alert('Debes agregar al menos 1 nombre/alias para vincular este token.');
    setIsCreating(true);

    const fullToken = newTokenPrefix + Math.random().toString(36).substring(2, 6).toUpperCase();

    const { data, error } = await supabase.from('clients').insert([{
      store_id: storeId,
      token: fullToken,
      alias_names: tempAliases
    }]).select().single();

    if (error) {
       alert('Error: ' + error.message);
    } else if (data) {
       setTempAliases([]);
       setNewTokenPrefix('CLI-');
       loadClients(); 
    }
    setIsCreating(false);
  };

  const deleteClient = async (id) => {
    if(confirm('¿Seguro que deseas eliminar este token de cliente? La deuda seguirá en el registro general pero el cliente no podrá acceder a verla.')) {
       await supabase.from('clients').delete().eq('id', id);
       setClients(clients.filter(c => c.id !== id));
    }
  };

  const openClientDetails = async (client) => {
    setModalLoading(true);
    setSelectedClient(client);
    
    // Recargar sus ventas en tiempo real buscando por alias_names o token
    const { data } = await supabase.from('sales')
          .select('*')
          .eq('store_id', storeId)
          .order('timestamp', { ascending: false });
          
    if (data) {
       setClientSales(data.filter(s => client.alias_names.includes(s.customer_name) || s.customer_name === client.token));
    }
    setModalLoading(false);
  };

  const payOffDebt = async (saleId) => {
    if(!confirm('¿Marcar esta deuda individual como pagada? Cambiará a pagada en Efectivo.')) return;
    
    // Update en supabase
    const { error } = await supabase.from('sales').update({ is_debt: false, payment_method: 'cash' }).eq('id', saleId);
    if (!error) {
       // Actualizar estado local
       setClientSales(clientSales.map(s => s.id === saleId ? { ...s, is_debt: false, payment_method: 'cash' } : s));
       loadClients(); // refrescar totales
       if(onDashboardUpdate) onDashboardUpdate();
    }
  };

  const payOffAllDebt = async () => {
    if(!confirm('¿Marcar TODA la deuda de este cliente como pagada en efectivo?')) return;
    const debtIds = clientSales.filter(s => s.is_debt).map(s => s.id);
    if(debtIds.length === 0) return;

    const { error } = await supabase.from('sales').update({ is_debt: false, payment_method: 'cash' }).in('id', debtIds);
    if (!error) {
       setClientSales(clientSales.map(s => s.is_debt ? { ...s, is_debt: false, payment_method: 'cash' } : s));
       // Resetear la alerta de pago del cliente tmb
       await supabase.from('clients').update({ payment_alert: false }).eq('id', selectedClient.id);
       setSelectedClient({ ...selectedClient, payment_alert: false });
       
       loadClients();
       if(onDashboardUpdate) onDashboardUpdate();
    }
  };

  const clearPaymentAlert = async (id) => {
    await supabase.from('clients').update({ payment_alert: false }).eq('id', id);
    setClients(clients.map(c => c.id === id ? { ...c, payment_alert: false } : c));
  };


  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500 relative">
      <div className="flex items-center justify-between">
         <h1 className="text-3xl font-bold tracking-tight text-white flex items-center gap-3">
            <Users className="w-8 h-8 text-indigo-400" />
            Control de Fiados y Clientes
         </h1>
      </div>
      
      <p className="text-slate-400 max-w-2xl text-lg">
        Genera tokens familiares para tus clientes habituales. Ellos podrán consultar su deuda online y avisarte cuando quieran saldarla. 
      </p>

      {/* Tarjeta de Generación de Clientes */}
      <div className="bg-[#161b22]/80 border border-slate-800 rounded-3xl p-6 lg:p-8 shadow-2xl relative overflow-hidden backdrop-blur-md">
        <h2 className="text-lg font-medium text-white mb-6 flex items-center gap-2">
           <UserPlus className="w-5 h-5 text-indigo-400" /> Generar Token de Cliente
        </h2>
        
        <div className="flex flex-col lg:flex-row gap-8">
           <form onSubmit={createClientToken} className="flex-1 space-y-4">
              <div>
                 <label className="text-xs font-bold text-slate-500 uppercase tracking-widest mb-2 block">Nombres vinculados (Alias)</label>
                 <div className="flex gap-2">
                   <input 
                     type="text" 
                     placeholder="Ej. Familia Sanchez" 
                     value={newAlias}
                     onChange={(e) => setNewAlias(e.target.value)}
                     onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); addAliasToTemp(); } }}
                     className="flex-1 bg-[#0b0f14] border border-slate-700 text-white px-4 py-3 rounded-xl focus:outline-none focus:ring-2 focus:ring-indigo-500/50"
                     disabled={isCreating || tempAliases.length >= 7}
                   />
                   <button type="button" onClick={addAliasToTemp} disabled={tempAliases.length >= 7} className="bg-slate-800 hover:bg-slate-700 text-white px-4 py-3 rounded-xl font-bold">Añadir</button>
                 </div>
                 <p className="text-slate-500 text-xs mt-2">Puedes añadir hasta 7 nombres o variaciones que los vendedores podrían usar (Ej. "Juan S", "Juan Sanchez").</p>
              </div>

              {tempAliases.length > 0 && (
                 <div className="flex flex-wrap gap-2 pt-2">
                    {tempAliases.map(alias => (
                       <span key={alias} className="inline-flex items-center gap-2 px-3 py-1.5 bg-indigo-500/10 text-indigo-300 border border-indigo-500/30 rounded-lg text-sm font-medium">
                          {alias}
                          <button type="button" onClick={() => removeAliasFromTemp(alias)} className="text-indigo-400 hover:text-rose-400"><Trash2 className="w-4 h-4" /></button>
                       </span>
                    ))}
                 </div>
              )}

              <div className="pt-2">
                 <button 
                   type="submit" 
                   disabled={isCreating || tempAliases.length === 0}
                   className="bg-indigo-600 hover:bg-indigo-500 text-white px-8 py-3.5 rounded-xl font-semibold transition-all shadow-lg active:scale-95 flex items-center justify-center gap-2 w-full lg:w-auto"
                 >
                   {isCreating ? <Loader2 className="w-5 h-5 animate-spin"/> : 'Crear Token'}
                 </button>
              </div>
           </form>
           
           <div className="lg:w-1/3 bg-indigo-900/10 border border-indigo-500/20 p-6 rounded-2xl flex flex-col justify-center items-center text-center">
               <WalletCards className="w-12 h-12 text-indigo-400 mb-4 opacity-75" />
               <h3 className="text-indigo-300 font-bold mb-2">Portal para Clientes</h3>
               <p className="text-slate-400 text-sm">Entrégale a tu cliente su Token para que ingrese desde su celular a ver cuánto te debe a través de tu misma web web.</p>
           </div>
        </div>
      </div>

      {loading && clients.length === 0 && (
         <div className="flex justify-center p-12"><Loader2 className="w-10 h-10 text-indigo-500 animate-spin"/></div>
      )}

      {/* Grid de Cartas de Clientes */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {clients.map((client) => {
           // Lógica de colores Dinámicos
           let borderColor = 'border-slate-800 hover:border-indigo-500/40';
           let bgHeader = 'bg-slate-800/20 text-slate-300';
           let statusText = 'Al Día';
           
           if (client.payment_alert) {
             borderColor = 'border-rose-500 shadow-rose-500/20 shadow-lg';
             bgHeader = 'bg-rose-500 text-white';
             statusText = '🚨 QUIERE PAGAR SO DEUDA';
           } else if (client.totalDebt > 0) {
             borderColor = 'border-orange-500/50 hover:border-orange-500';
             bgHeader = 'bg-orange-500/20 text-orange-400';
             statusText = 'Fiado Pendiente';
           } else {
             borderColor = 'border-emerald-500/30 hover:border-emerald-500';
             bgHeader = 'bg-emerald-500/10 text-emerald-400';
             statusText = 'Todo Pagado (Verde)';
           }

           return (
             <div key={client.id} className={`flex flex-col bg-[#161b22] border rounded-3xl overflow-hidden shadow-xl transition-all duration-300 relative group ${borderColor}`}>
                <div className={`px-5 py-2 flex items-center justify-center font-bold text-xs uppercase tracking-widest ${bgHeader}`}>
                   {statusText}
                </div>
                
                <div className="p-6 flex-1 flex flex-col">
                  <div className="flex justify-between items-start mb-4">
                     <div>
                        <p className="text-slate-500 text-xs font-bold uppercase mb-1">Token Cliente</p>
                        <span className="font-mono bg-[#0b0f14] text-white px-3 py-1.5 rounded-lg text-lg border border-slate-700 font-extrabold tracking-widest inline-flex">
                          {client.token}
                        </span>
                     </div>
                     <button onClick={() => deleteClient(client.id)} className="text-slate-600 hover:text-rose-400 transition-colors p-2 rounded-xl">
                        <Trash2 className="w-5 h-5" />
                     </button>
                  </div>

                  <div className="mb-6 flex-1">
                     <p className="text-slate-500 text-xs font-bold uppercase mb-2">Familias / Nombres</p>
                     <div className="flex flex-wrap gap-1.5">
                        {client.alias_names.map(alias => (
                           <span key={alias} className="px-2 py-1 bg-white/5 border border-white/10 rounded text-xs text-slate-300">{alias}</span>
                        ))}
                     </div>
                  </div>
                  
                  {/* Totales del cliente */}
                  <div className="grid grid-cols-2 gap-2 mb-4">
                     <div className="bg-[#0b0f14] border border-slate-800 rounded-xl p-3 text-center">
                        <p className="text-orange-400 text-[10px] font-bold uppercase mb-1 flex justify-center items-center gap-1"><AlertCircle className="w-3 h-3"/> Debe</p>
                        <p className="text-orange-500 font-extrabold text-xl">${client.totalDebt.toFixed(2)}</p>
                     </div>
                     <div className="bg-[#0b0f14] border border-slate-800 rounded-xl p-3 text-center">
                        <p className="text-emerald-400 text-[10px] font-bold uppercase mb-1 flex justify-center items-center gap-1"><CheckCircle2 className="w-3 h-3"/> Pagado</p>
                        <p className="text-emerald-500 font-extrabold text-xl">${client.totalPaid.toFixed(2)}</p>
                     </div>
                  </div>

                  {client.payment_alert && (
                     <button onClick={() => clearPaymentAlert(client.id)} className="w-full mb-3 bg-rose-500/10 text-rose-400 border border-rose-500/20 py-2 rounded-xl font-bold text-sm hover:bg-rose-500 hover:text-white transition-colors">
                        Descartar Alerta de Pago
                     </button>
                  )}

                  <button 
                     onClick={() => openClientDetails(client)}
                     className="w-full bg-slate-800 hover:bg-slate-700 text-white font-semibold py-3 rounded-xl transition-colors flex justify-center items-center gap-2"
                  >
                     <Receipt className="w-4 h-4"/> Gestionar Consumos
                  </button>
                </div>
             </div>
           );
        })}
      </div>

      {/* Modal / Overlay Gestión de Consumos */}
      {selectedClient && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-in fade-in">
           <div className="bg-[#161b22] border border-slate-700 w-full max-w-4xl max-h-[85vh] rounded-3xl overflow-hidden shadow-2xl flex flex-col slide-in-from-bottom-8">
              
              {/* Header Modal */}
              <div className="p-6 border-b border-slate-800 bg-[#0d1117] flex justify-between items-start">
                 <div>
                   <h2 className="text-2xl font-bold text-white flex items-center gap-3">
                     <WalletCards className="text-indigo-400 w-7 h-7" /> Entradas de {selectedClient.token}
                   </h2>
                   <div className="flex gap-2 mt-2">
                     {selectedClient.alias_names.map(a => <span key={a} className="text-xs text-slate-400 bg-white/5 px-2 py-1 rounded">{a}</span>)}
                   </div>
                 </div>
                 <button onClick={() => { setSelectedClient(null); loadClients(); }} className="p-2 text-slate-400 hover:text-white hover:bg-slate-800 rounded-xl transition-colors">
                    <ChevronDown className="w-6 h-6"/>
                 </button>
              </div>
              
              {/* Toolbar Actions Modal */}
              <div className="p-4 bg-indigo-900/10 border-b border-indigo-500/10 flex justify-between items-center">
                 <p className="text-indigo-200">Deuda Pendiente General: <span className="font-extrabold text-orange-400 text-xl ml-2">${clientSales.filter(s=>s.is_debt).reduce((acc, s)=> acc + Number(s.amount), 0).toFixed(2)}</span></p>
                 <button onClick={payOffAllDebt} className="bg-emerald-600 hover:bg-emerald-500 text-white px-5 py-2.5 rounded-xl font-bold shadow-lg shadow-emerald-500/20 active:scale-95 transition-all flex items-center gap-2">
                    <CheckCircle2 className="w-5 h-5"/> Liquidar TODO a Efectivo
                 </button>
              </div>

              {/* Lista Scroll Modal */}
              <div className="flex-1 overflow-auto p-6 bg-[#0b0f14]">
                 {modalLoading ? (
                    <div className="flex justify-center p-10"><Loader2 className="w-8 h-8 text-indigo-500 animate-spin"/></div>
                 ) : clientSales.length === 0 ? (
                    <div className="text-center p-10 mt-10 text-slate-500 font-medium">No hay consumos registrados bajo los nombres de este token.</div>
                 ) : (
                    <div className="space-y-4">
                       {clientSales.map((sale) => (
                          <div key={sale.id} className={`flex flex-col md:flex-row items-start md:items-center justify-between p-5 border rounded-2xl transition-colors ${sale.is_debt ? 'bg-orange-900/10 border-orange-500/30' : 'bg-[#161b22] border-slate-800'}`}>
                             
                             <div className="flex items-center gap-4 mb-3 md:mb-0">
                                <div className={`w-12 h-12 rounded-full flex items-center justify-center ${sale.is_debt ? 'bg-orange-500/20 text-orange-500' : 'bg-emerald-500/10 text-emerald-400'}`}>
                                   {sale.is_debt ? <AlertCircle className="w-6 h-6"/> : <Receipt className="w-6 h-6"/>}
                                </div>
                                <div>
                                   <p className="text-white font-bold text-lg">{sale.product_description}</p>
                                   <p className="text-slate-400 text-sm">Venta a: <span className="text-indigo-300 font-medium">{sale.customer_name}</span> • {new Date(sale.timestamp).toLocaleString()}</p>
                                </div>
                             </div>
                             
                             <div className="flex items-center gap-6 w-full md:w-auto">
                                <div className="text-right flex-1 md:flex-none">
                                   <p className={`font-black text-2xl ${sale.is_debt ? 'text-orange-500' : 'text-emerald-400'}`}>${Number(sale.amount).toFixed(2)}</p>
                                   <p className="text-xs font-semibold text-slate-500 uppercase mt-1">
                                      {sale.is_debt ? 'Fiado (Debe)' : `Pagado: ${sale.payment_method}`}
                                   </p>
                                </div>
                                {sale.is_debt && (
                                  <button onClick={() => payOffDebt(sale.id)} className="bg-emerald-500/10 hover:bg-emerald-500 text-emerald-500 hover:text-white border border-emerald-500/50 p-3 rounded-xl transition-all" title="Marcar como pagado (Efectivo)">
                                     <CheckCircle2 className="w-6 h-6"/>
                                  </button>
                                )}
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

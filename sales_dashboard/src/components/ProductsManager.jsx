import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabaseClient';
import { Package, PlusCircle, Trash2, Loader2, Tag, Edit3, Check, X, Box, Search, AlertTriangle, Plus, Minus } from 'lucide-react';
import { toast } from 'sonner';

export default function ProductsManager({ storeId }) {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  
  // Fomulario Minimalista
  const [showAddForm, setShowAddForm] = useState(false);
  const [adding, setAdding] = useState(false);
  const [name, setName] = useState('');
  const [category, setCategory] = useState('General');
  const [price, setPrice] = useState('');
  const [stock, setStock] = useState('0');

  // Categorías Predefinidas
  const CATALOG_CATEGORIES = [
    'Almacén', 'Bebidas (Sin Alcohol)', 'Bebidas (Con Alcohol)', 'Lácteos y Frescos',
    'Golosinas y Snacks', 'Limpieza', 'Perfumería e Higiene',
    'Fiambres y Quesos', 'Congelados', 'Panadería', 'Verdulería', 'Carnicería', 'General'
  ];

  // Filtro de Categorías (Pestañas) y Buscador
  const [activeCategory, setActiveCategory] = useState('Todas');
  const [searchTerm, setSearchTerm] = useState('');

  // Estados de edición en línea
  const [editingId, setEditingId] = useState(null);
  const [editPrice, setEditPrice] = useState('');
  const [editStock, setEditStock] = useState('');
  const [savingEdit, setSavingEdit] = useState(false);

  useEffect(() => {
    if (storeId) loadProducts();
  }, [storeId]);

  const loadProducts = async () => {
    setLoading(true);
    const { data } = await supabase.from('products').select('*').eq('store_id', storeId).order('category', { ascending: true }).order('name', { ascending: true });
    if (data) setProducts(data);
    setLoading(false);
  };

  const addProduct = async (e) => {
    e.preventDefault();
    if (!name || !price) return;
    setAdding(true);

    const finalCategory = category.trim() === '' ? 'General' : category.trim();

    const { data, error } = await supabase.from('products').insert([{
      store_id: storeId,
      name,
      category: finalCategory,
      price: parseFloat(price),
      stock: parseInt(stock) || 0,
    }]).select().single();

    if (error) {
      toast.error(error.message);
    } else if (data) {
      setProducts([...products, data].sort((a,b) => a.name.localeCompare(b.name)));
      setName('');
      setCategory('General');
      setPrice('');
      setStock('0');
      setShowAddForm(false);
      setActiveCategory(finalCategory); // Saltar a la pestaña nueva
    }
    setAdding(false);
  };

  const deleteProduct = async (id) => {
    if (confirm('¿Eliminar producto de forma definitiva?')) {
      await supabase.from('products').delete().eq('id', id);
      setProducts(products.filter(p => p.id !== id));
    }
  };

  const startEditing = (p) => {
    setEditingId(p.id);
    setEditPrice(p.price.toString());
    setEditStock(p.stock.toString());
  };

  const saveEdit = async (id) => {
    setSavingEdit(true);
    const { data, error } = await supabase.from('products').update({
       price: parseFloat(editPrice), 
       stock: parseInt(editStock) || 0
    }).eq('id', id).select().single();
    
    if (!error && data) {
       setProducts(products.map(p => p.id === id ? data : p));
       setEditingId(null);
    } else {
       toast.error(error?.message || "Error al actualizar");
    }
    setSavingEdit(false);
  };


  const updateStockQuickly = async (p, delta) => {
    const newStock = Math.max(0, p.stock + delta);
    // Optimistic UI update
    setProducts(products.map(item => item.id === p.id ? { ...item, stock: newStock } : item));
    const { error } = await supabase.from('products').update({ stock: newStock }).eq('id', p.id);
    if (error) {
       toast.error(error.message);
       loadProducts(); // Revert on error
    }
  };

  // Derivar categorías únicas
  const categories = ['Todas', 'En Escasez', ...new Set(products.map(p => p.category))];
  const filteredProducts = products.filter(p => {
    if (searchTerm && !p.name.toLowerCase().includes(searchTerm.toLowerCase())) return false;
    if (activeCategory === 'En Escasez') return p.stock <= 5;
    if (activeCategory !== 'Todas') return p.category === activeCategory;
    return true;
  });

  return (
    <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500">
      <div className="flex items-center justify-between">
         <div className="flex items-center gap-3">
           <Package className="w-8 h-8 text-indigo-400" />
           <h1 className="text-3xl font-bold tracking-tight text-white">Catálogo</h1>
         </div>
         <button 
            onClick={() => setShowAddForm(!showAddForm)}
            className="bg-indigo-600/20 text-indigo-400 hover:bg-indigo-600 hover:text-white px-5 py-2.5 rounded-full font-bold flex items-center gap-2 border border-indigo-500/30 transition-all shadow-lg active:scale-95"
         >
            {showAddForm ? <X className="w-5 h-5"/> : <PlusCircle className="w-5 h-5"/>}
            {showAddForm ? 'Cancelar' : 'Añadir Producto'}
         </button>
      </div>

      {/* Formulario Agregar Producto Minimalista */}
      {showAddForm && (
        <div className="bg-[#161b22] border border-indigo-500/30 rounded-2xl p-4 shadow-2xl relative overflow-hidden animate-in fade-in slide-in-from-top-4">
          <form onSubmit={addProduct} className="flex flex-col md:flex-row gap-3 relative z-10 w-full">
            <input type="text" placeholder="Nombre (Ej. Gaseosa Cola)" value={name} onChange={(e) => setName(e.target.value)} className="flex-1 bg-[#0b0f14] border border-slate-700 text-white px-4 py-2.5 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500/50 text-sm" required disabled={adding} />
            <select 
               value={category} 
               onChange={(e) => setCategory(e.target.value)} 
               className="w-[160px] bg-[#0b0f14] border border-slate-700 text-slate-300 px-3 py-2.5 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500/50 text-sm disabled:opacity-50 appearance-none" 
               disabled={adding}
            >
               {CATALOG_CATEGORIES.map(cat => <option key={cat} value={cat}>{cat}</option>)}
            </select>
            <div className="flex items-center bg-[#0b0f14] border border-slate-700 rounded-lg px-3 w-[120px]">
               <span className="text-slate-500 text-sm">$</span>
               <input type="number" step="0.01" placeholder="Precio" value={price} onChange={(e) => setPrice(e.target.value)} className="bg-transparent text-white pl-2 py-2.5 focus:outline-none w-full text-sm appearance-none" required disabled={adding} />
            </div>
            <div className="flex items-center bg-[#0b0f14] border border-slate-700 rounded-lg px-3 w-[120px]">
               <span className="text-slate-500 text-sm font-medium">#</span>
               <input type="number" placeholder="Stock" value={stock} onChange={(e) => setStock(e.target.value)} className="bg-transparent text-white pl-2 py-2.5 focus:outline-none w-full text-sm" disabled={adding} />
            </div>
            <button type="submit" disabled={adding} className="bg-indigo-600 hover:bg-indigo-500 text-white px-6 py-2.5 rounded-lg font-bold transition-all shadow-md active:scale-95 flex items-center justify-center gap-2 text-sm whitespace-nowrap">
              {adding ? <Loader2 className="w-4 h-4 animate-spin"/> : 'Guardar'}
            </button>
          </form>
        </div>
      )}

      {/* Filtros, Buscador y Categorías */}
      {products.length > 0 && (
         <div className="flex flex-col sm:flex-row items-center gap-4 mb-2">
            <div className="relative w-full sm:w-80 flex-shrink-0">
               <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
               <input 
                  type="search" 
                  placeholder="Buscar producto..." 
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="w-full bg-[#161b22] border border-slate-700 text-white pl-10 pr-4 py-2.5 rounded-xl focus:outline-none focus:ring-2 focus:ring-indigo-500/50 shadow-sm"
               />
            </div>
            <div className="flex items-center gap-2 overflow-x-auto w-full pb-2 sm:pb-0 scrollbar-hide">
               {categories.map(cat => (
                  <button 
                     key={cat} 
                     onClick={() => setActiveCategory(cat)}
                     className={`flex items-center gap-2 px-5 py-2.5 rounded-xl font-bold transition-all whitespace-nowrap shadow-sm border ${
                        activeCategory === cat 
                           ? (cat === 'En Escasez' ? 'bg-amber-500 text-slate-900 border-amber-400 shadow-amber-500/30' : 'bg-indigo-600 text-white border-indigo-500 shadow-indigo-500/30') 
                           : 'bg-[#161b22] text-slate-400 border-slate-800 hover:bg-slate-800 hover:text-white'
                     }`}
                  >
                     {cat === 'Todas' && <Package className="w-4 h-4"/>}
                     {cat === 'En Escasez' && <AlertTriangle className={`w-4 h-4 ${activeCategory === 'En Escasez' ? 'text-slate-900' : 'text-amber-500 animate-pulse'}`} />}
                     {cat !== 'Todas' && cat !== 'En Escasez' && <Box className="w-4 h-4 opacity-70"/>}
                     {cat}
                  </button>
               ))}
            </div>
         </div>
      )}

      {/* Tarjetas de Productos (Grid Dinámico) */}
      <div className="bg-[#0d1117] border border-slate-800 rounded-3xl p-6 shadow-xl min-h-[160px]">
        {loading ? (
             <div className="flex justify-center items-center py-20"><Loader2 className="w-8 h-8 animate-spin text-indigo-500"/></div>
        ) : filteredProducts.length === 0 ? (
             <div className="py-20 text-center text-slate-500 flex flex-col items-center gap-3">
                <Box className="w-12 h-12 opacity-20"/>
                <p>No se encontraron productos.</p>
             </div>
        ) : (
           <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
               {filteredProducts.map((p) => {
                  const isEditing = editingId === p.id;
                  const isLowStock = p.stock <= 5;

                  return (
                     <div key={p.id} className={`group bg-[#161b22] border rounded-2xl p-5 flex flex-col shadow-lg transition-all ${isLowStock ? 'border-amber-500/50 hover:border-amber-500 shadow-amber-500/10' : 'border-slate-800 hover:border-indigo-500/50 hover:shadow-indigo-500/10'}`}>
                        <div className="flex justify-between items-start mb-3">
                           <div className="pr-2">
                              <h3 className="text-white font-bold text-lg leading-tight mb-1">{p.name}</h3>
                              <span className="text-xs text-slate-500 bg-[#0b0f14] px-2 py-0.5 rounded-md border border-slate-800">{p.category}</span>
                           </div>
                           {!isEditing && (
                              <div className="flex opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0 bg-[#0b0f14] p-1 rounded-lg border border-slate-800">
                                 <button onClick={() => startEditing(p)} className="text-slate-500 hover:text-indigo-400 p-1.5 hover:bg-indigo-500/10 rounded-md"><Edit3 className="w-4 h-4"/></button>
                                 <button onClick={() => deleteProduct(p.id)} className="text-slate-600 hover:text-rose-400 p-1.5 hover:bg-rose-500/10 rounded-md"><Trash2 className="w-4 h-4"/></button>
                              </div>
                           )}
                        </div>

                        <div className="flex-1"></div>

                        {isEditing ? (
                           <div className="space-y-3 mt-4 bg-[#0b0f14] p-3 rounded-xl border border-slate-800 animate-in fade-in">
                              <div>
                                 <label className="text-xs text-slate-500 font-bold uppercase tracking-wider mb-1 block">Precio ($)</label>
                                 <input type="number" step="0.01" value={editPrice} onChange={(e) => setEditPrice(e.target.value)} className="w-full bg-[#161b22] border border-emerald-500/50 text-emerald-400 font-bold px-3 py-2 rounded-lg focus:outline-none" autoFocus />
                              </div>
                              <div>
                                 <label className="text-xs text-slate-500 font-bold uppercase tracking-wider mb-1 block">Stock Total</label>
                                 <input type="number" value={editStock} onChange={(e) => setEditStock(e.target.value)} className="w-full bg-[#161b22] border border-indigo-500/50 text-white font-bold px-3 py-2 rounded-lg focus:outline-none" />
                              </div>
                              <div className="flex gap-2 pt-2">
                                 <button onClick={() => saveEdit(p.id)} disabled={savingEdit} className="flex-1 bg-emerald-500/20 text-emerald-400 hover:bg-emerald-500 hover:text-white py-2 rounded-lg font-bold flex items-center justify-center transition-colors">
                                    {savingEdit ? <Loader2 className="w-4 h-4 animate-spin"/> : <Check className="w-4 h-4" />}
                                 </button>
                                 <button onClick={() => setEditingId(null)} disabled={savingEdit} className="flex-1 bg-slate-800 text-slate-400 hover:bg-slate-700 hover:text-white py-2 rounded-lg font-bold flex items-center justify-center transition-colors">
                                    <X className="w-4 h-4" />
                                 </button>
                              </div>
                           </div>
                        ) : (
                           <div className="mt-4 flex items-end justify-between border-t border-slate-800/60 pt-4 relative">
                              <div>
                                 <p className="text-xs text-slate-500 font-bold uppercase tracking-wider mb-0.5">Precio</p>
                                 <p className="text-2xl font-black text-emerald-400 tracking-tight">${Number(p.price).toFixed(2)}</p>
                              </div>
                              <div className="flex flex-col items-end">
                                 <p className="text-xs text-slate-500 font-bold uppercase tracking-wider mb-1">Stock Físico</p>
                                 <div className={`flex items-center gap-1 bg-[#0b0f14] p-1 rounded-lg border shadow-inner ${isLowStock ? 'border-amber-500/30 bg-amber-500/5' : 'border-slate-800'}`}>
                                    <button onClick={() => updateStockQuickly(p, -1)} className="p-1.5 text-slate-400 hover:text-white hover:bg-rose-500 rounded-md transition-colors"><Minus className="w-4 h-4"/></button>
                                    <span className={`font-black tracking-tight w-8 text-center text-lg ${isLowStock ? 'text-amber-500' : 'text-white'}`}>{p.stock}</span>
                                    <button onClick={() => updateStockQuickly(p, 1)} className="p-1.5 text-slate-400 hover:text-white hover:bg-emerald-500 rounded-md transition-colors"><Plus className="w-4 h-4"/></button>
                                 </div>
                              </div>
                           </div>
                        )}
                     </div>
                  );
               })}
           </div>
        )}
      </div>
    </div>
  );
}

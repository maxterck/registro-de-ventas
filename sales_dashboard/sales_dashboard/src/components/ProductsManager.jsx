import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabaseClient';
import { Package, PlusCircle, Trash2, Loader2, Tag, Edit3, Check, X, Box } from 'lucide-react';

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

  // Filtro de Categorías (Pestañas)
  const [activeCategory, setActiveCategory] = useState('Todas');

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
      alert(error.message);
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
       alert(error?.message || "Error al actualizar");
    }
    setSavingEdit(false);
  };


  // Derivar categorías únicas
  const categories = ['Todas', ...new Set(products.map(p => p.category))];
  const filteredProducts = activeCategory === 'Todas' ? products : products.filter(p => p.category === activeCategory);

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

      {/* Pestañas de Categorías estilo Botones/Íconos */}
      {products.length > 0 && (
         <div className="flex items-center gap-2 overflow-x-auto pb-2 scrollbar-hide py-2">
            {categories.map(cat => (
               <button 
                  key={cat} 
                  onClick={() => setActiveCategory(cat)}
                  className={`flex items-center gap-2 px-5 py-2.5 rounded-xl font-bold transition-all whitespace-nowrap shadow-sm border ${
                     activeCategory === cat 
                        ? 'bg-indigo-600 text-white border-indigo-500 shadow-indigo-500/30' 
                        : 'bg-[#161b22] text-slate-400 border-slate-800 hover:bg-slate-800 hover:text-white'
                  }`}
               >
                  {cat === 'Todas' ? <Package className="w-4 h-4"/> : <Box className="w-4 h-4 opacity-70"/>}
                  {cat}
               </button>
            ))}
         </div>
      )}

      {/* Lista de Productos Agrupados */}
      <div className="bg-[#161b22] border border-slate-800 rounded-3xl overflow-hidden shadow-xl min-h-[160px]">
        {loading ? (
             <div className="flex justify-center items-center p-12"><Loader2 className="w-8 h-8 animate-spin text-indigo-500"/></div>
        ) : filteredProducts.length === 0 ? (
             <div className="p-12 text-center text-slate-500 flex flex-col items-center gap-3">
                <Box className="w-12 h-12 opacity-20"/>
                <p>No hay productos en esta categoría.</p>
             </div>
        ) : (
          <div className="overflow-x-auto">
             <table className="w-full text-left border-collapse min-w-[600px]">
               <thead>
                 <tr className="bg-slate-800/40 text-slate-400 text-[10px] sm:text-xs font-bold uppercase tracking-widest border-b border-slate-800">
                   <th className="p-4 sm:p-5">Producto</th>
                   <th className="p-4 sm:p-5 w-32">Precio ($)</th>
                   <th className="p-4 sm:p-5 w-32">Stock</th>
                   <th className="p-4 sm:p-5 w-24 text-right">Acciones</th>
                 </tr>
               </thead>
               <tbody className="divide-y divide-slate-800/50">
                 {filteredProducts.map((p) => {
                    const isEditing = editingId === p.id;

                    return (
                       <tr key={p.id} className="hover:bg-white/[0.02] transition-colors group">
                         <td className="p-4 sm:p-5">
                            <span className="text-white font-bold text-base sm:text-lg block">{p.name}</span>
                            {activeCategory === 'Todas' && <span className="text-xs text-slate-500 mt-0.5">{p.category}</span>}
                         </td>
                         
                         {/* Cell PRECIO */}
                         <td className="p-4 sm:p-5">
                            {isEditing ? (
                               <input 
                                  type="number" step="0.01" value={editPrice} 
                                  onChange={(e) => setEditPrice(e.target.value)}
                                  className="w-full bg-[#0b0f14] border border-emerald-500/50 text-emerald-400 font-bold px-3 py-1.5 rounded focus:outline-none focus:ring-2 focus:ring-emerald-500"
                                  autoFocus
                               />
                            ) : (
                               <span className="text-emerald-400 font-extrabold tracking-wide sm:text-lg">${Number(p.price).toFixed(2)}</span>
                            )}
                         </td>

                         {/* Cell STOCK */}
                         <td className="p-4 sm:p-5">
                            {isEditing ? (
                               <input 
                                  type="number" value={editStock} 
                                  onChange={(e) => setEditStock(e.target.value)}
                                  className="w-full bg-[#0b0f14] border border-indigo-500/50 text-white font-bold px-3 py-1.5 rounded focus:outline-none focus:ring-2 focus:ring-indigo-500"
                               />
                            ) : (
                               <span className={`inline-flex items-center px-3 py-1 rounded-md text-sm font-bold ${
                                   p.stock > 0 ? 'bg-indigo-500/10 text-indigo-300 border border-indigo-500/20' : 'bg-rose-500/10 text-rose-400 border border-rose-500/20'
                               }`}>
                                   {p.stock}
                               </span>
                            )}
                         </td>

                         {/* Cell ACCIONES */}
                         <td className="p-4 sm:p-5 text-right flex items-center justify-end gap-1">
                            {isEditing ? (
                               <>
                                  <button onClick={() => saveEdit(p.id)} disabled={savingEdit} className="text-emerald-500 hover:bg-emerald-500/20 p-2 rounded-lg transition-colors">
                                     {savingEdit ? <Loader2 className="w-5 h-5 animate-spin"/> : <Check className="w-5 h-5" />}
                                  </button>
                                  <button onClick={() => setEditingId(null)} disabled={savingEdit} className="text-slate-500 hover:bg-slate-700 p-2 rounded-lg transition-colors">
                                     <X className="w-5 h-5" />
                                  </button>
                                </>
                            ) : (
                               <>
                                  <button onClick={() => startEditing(p)} className="text-slate-500 hover:text-indigo-400 transition-colors p-2 hover:bg-indigo-500/10 rounded-lg" title="Editar precio y stock">
                                     <Edit3 className="w-5 h-5" />
                                  </button>
                                  <button onClick={() => deleteProduct(p.id)} className="text-slate-600 hover:text-rose-400 transition-colors p-2 hover:bg-rose-500/10 rounded-lg">
                                     <Trash2 className="w-5 h-5" />
                                  </button>
                               </>
                            )}
                         </td>
                       </tr>
                    )
                 })}
               </tbody>
             </table>
          </div>
        )}
      </div>
    </div>
  );
}

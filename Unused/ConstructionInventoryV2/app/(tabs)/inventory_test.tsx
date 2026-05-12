import React from 'react';
import { StyleSheet, Text, View } from 'react-native';

export default function InventoryScreen() {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>Materials Inventory</Text>
      <Text>This is where your Firebase data will appear.</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: '#fff' },
  title: { fontSize: 24, fontWeight: 'bold' },
});

// import React, { useState, useEffect } from 'react';
// import { StyleSheet, Text, View, TextInput, TouchableOpacity, FlatList, Alert } from 'react-native';
// import { db } from '../../firebaseConfig'; 
// import { collection, addDoc, onSnapshot, query, deleteDoc, doc, serverTimestamp } from "firebase/firestore";

// export default function InventoryManager() {
//   const [materialName, setMaterialName] = useState('');
//   const [inventory, setInventory] = useState<any[]>([]);

//   // --- READ: Real-time Listener ---
//   useEffect(() => {
//     const q = query(collection(db, "materials"));
//     const unsubscribe = onSnapshot(q, (querySnapshot) => {
//       const items: any[] = [];
//       querySnapshot.forEach((doc) => {
//         items.push({ ...doc.data(), id: doc.id });
//       });
//       setInventory(items);
//     });
//     return () => unsubscribe(); // Clean up on unmount
//   }, []);

//   // --- CREATE: Add Item ---
//   const addItem = async () => {
//     if (materialName.trim() === '') return;
//     try {
//       await addDoc(collection(db, "materials"), {
//         name: materialName,
//         timestamp: serverTimestamp(),
//       });
//       setMaterialName('');
//     } catch (e) {
//       console.error("Error adding: ", e);
//     }
//   };

//   // --- DELETE: Remove Item ---
//   const deleteItem = async (id: string) => {
//     try {
//       await deleteDoc(doc(db, "materials", id));
//     } catch (e) {
//       Alert.alert("Error", "Could not delete item");
//     }
//   };

//   return (
//     <View style={styles.container}>
//       <Text style={styles.header}>Construction Inventory</Text>
      
//       <View style={styles.inputContainer}>
//         <TextInput 
//           style={styles.input} 
//           placeholder="Enter material..." 
//           value={materialName}
//           onChangeText={setMaterialName}
//         />
//         <TouchableOpacity style={styles.addButton} onPress={addItem}>
//           <Text style={{color: 'white', fontWeight: 'bold'}}>Add</Text>
//         </TouchableOpacity>
//       </View>

//       <FlatList
//         data={inventory}
//         keyExtractor={(item) => item.id}
//         renderItem={({ item }) => (
//           <View style={styles.itemRow}>
//             <Text style={styles.itemText}>{item.name}</Text>
//             <TouchableOpacity onPress={() => deleteItem(item.id)}>
//               <Text style={styles.deleteText}>Delete</Text>
//             </TouchableOpacity>
//           </View>
//         )}
//       />
//     </View>
//   );
// }

// const styles = StyleSheet.create({
//   container: { flex: 1, padding: 40, backgroundColor: '#f8f9fa' },
//   header: { fontSize: 24, fontWeight: 'bold', marginBottom: 20, textAlign: 'center' },
//   inputContainer: { flexDirection: 'row', marginBottom: 20 },
//   input: { flex: 1, borderBottomWidth: 1, borderColor: '#ccc', marginRight: 10, padding: 8 },
//   addButton: { backgroundColor: '#28a745', padding: 12, borderRadius: 6 },
//   itemRow: { flexDirection: 'row', justifyContent: 'space-between', padding: 15, backgroundColor: '#fff', marginBottom: 10, borderRadius: 8, elevation: 2 },
//   itemText: { fontSize: 18 },
//   deleteText: { color: '#dc3545', fontWeight: 'bold' }
// });
"use client";

import React, { useState } from "react";

export default function PlaylistsAdminPage() {
  const [playlists, setPlaylists] = useState([
    { id: "pl-1", name: "ورد قيام الليل الخاشع", tracksCount: 14, duration: "3 ساعات و 20 دقيقة", type: "منسقة مركزياً" },
    { id: "pl-2", name: "تلاوات الحرمين الشريفين النادرة", tracksCount: 22, duration: "4 ساعات و 10 دقائق", type: "منسقة مركزياً" },
    { id: "pl-3", name: "المصحف المعلم للأطفال", tracksCount: 30, duration: "ساعتان", type: "تعليمي" }
  ]);

  return (
    <div>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1.5rem" }}>
        <div>
          <h1 style={{ fontSize: "1.8rem", fontWeight: 700, margin: 0 }}>قوائم التشغيل المركزية</h1>
          <p style={{ color: "#2E9E9E", marginTop: "0.2rem" }}>إدارة سلاسل التلاوات وقوائم التشغيل المعروضة للمستخدمين</p>
        </div>
        <button
          onClick={() => {
            const name = prompt("أدخل اسم قائمة التشغيل الجديدة:");
            if (name) {
              setPlaylists([...playlists, { id: `pl-${Date.now()}`, name, tracksCount: 0, duration: "0 دقيقة", type: "مخصصة" }]);
            }
          }}
          style={{ backgroundColor: "#2E9E9E", color: "#fff", border: "none", padding: "0.75rem 1.5rem", borderRadius: "8px", fontWeight: 600, cursor: "pointer" }}
        >
          ➕ إنشاء قائمة جديدة
        </button>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))", gap: "1.2rem" }}>
        {playlists.map((pl) => (
          <div key={pl.id} style={{ backgroundColor: "#172235", padding: "1.5rem", borderRadius: "12px", border: "1px solid #243B6B" }}>
            <h3 style={{ fontSize: "1.1rem", fontWeight: 700, margin: "0 0 0.5rem 0" }}>{pl.name}</h3>
            <div style={{ color: "#2E9E9E", fontSize: "0.85rem", marginBottom: "1rem" }}>{pl.type}</div>
            <div style={{ fontSize: "0.9rem", color: "#9DAEC6", marginBottom: "0.4rem" }}>عدد التلاوات: {pl.tracksCount}</div>
            <div style={{ fontSize: "0.9rem", color: "#9DAEC6", marginBottom: "1.2rem" }}>المدة الإجمالية: {pl.duration}</div>
            <div style={{ display: "flex", gap: "0.5rem" }}>
              <button style={{ backgroundColor: "#243B6B", color: "#fff", border: "none", padding: "0.5rem 1rem", borderRadius: "6px", cursor: "pointer", fontSize: "0.85rem" }}>ترتيب المسارات</button>
              <button style={{ backgroundColor: "transparent", color: "#EF4444", border: "1px solid #EF4444", padding: "0.5rem 1rem", borderRadius: "6px", cursor: "pointer", fontSize: "0.85rem" }}>حذف</button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

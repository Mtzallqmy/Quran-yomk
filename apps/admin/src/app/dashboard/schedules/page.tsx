"use client";

import React from "react";

export default function SchedulesAdminPage() {
  const schedules = [
    { title: "جدول فجر الجمعة (سورة الكهف وسورة السجدة)", station: "إذاعة التلاوات الخاشعة", type: "WEEKLY (أسبوعي)", time: "كل جمعة 05:00 ص", tz: "Asia/Riyadh", status: "نشط ومجدول" },
    { title: "تلاوات الحرمين بعد العصر", station: "إذاعة تلاوات الحرمين", type: "DAILY (يومي)", time: "يومياً 03:45 م", tz: "Asia/Riyadh", status: "نشط ومجدول" },
    { title: "ختمة المصحف المرتل برواية ورش", station: "إذاعة المصحف المرتل", type: "ONE_TIME (مرة واحدة)", time: "2026-09-20 08:00 م", tz: "Asia/Riyadh", status: "قيد الانتظار" }
  ];

  return (
    <div>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1.5rem" }}>
        <div>
          <h1 style={{ fontSize: "1.8rem", fontWeight: 700, margin: 0 }}>الجداول الزمنية وأتمتة البث</h1>
          <p style={{ color: "#2E9E9E", marginTop: "0.2rem" }}>جدولة تشغيل التلاوات والمحطات عبر محرك الـ Scheduler مع ضمان Fencing الحصري</p>
        </div>
        <button
          onClick={() => alert("يرجى اختيار المحطة والوقت المحدد للجدولة الجديدة")}
          style={{ backgroundColor: "#2E9E9E", color: "#fff", border: "none", padding: "0.75rem 1.5rem", borderRadius: "8px", fontWeight: 600, cursor: "pointer" }}
        >
          ➕ إضافة جدول زمني
        </button>
      </div>

      <div style={{ backgroundColor: "#172235", borderRadius: "12px", border: "1px solid #243B6B", overflow: "hidden" }}>
        <table style={{ width: "100%", borderCollapse: "collapse", textAlign: "right" }}>
          <thead>
            <tr style={{ backgroundColor: "#0E1726", borderBottom: "1px solid #243B6B" }}>
              <th style={{ padding: "1rem" }}>اسم الجدول / الحدث</th>
              <th style={{ padding: "1rem" }}>المحطة المستهدفة</th>
              <th style={{ padding: "1rem" }}>النوع والتكرار</th>
              <th style={{ padding: "1rem" }}>الموعد المجدول</th>
              <th style={{ padding: "1rem" }}>المنطقة الزمنية</th>
              <th style={{ padding: "1rem" }}>الحالة</th>
            </tr>
          </thead>
          <tbody>
            {schedules.map((s, i) => (
              <tr key={i} style={{ borderBottom: "1px solid #243B6B" }}>
                <td style={{ padding: "1rem", fontWeight: 600 }}>{s.title}</td>
                <td style={{ padding: "1rem" }}>{s.station}</td>
                <td style={{ padding: "1rem", color: "#C77955" }}>{s.type}</td>
                <td style={{ padding: "1rem" }}>{s.time}</td>
                <td style={{ padding: "1rem", color: "#9DAEC6" }}>{s.tz}</td>
                <td style={{ padding: "1rem", color: "#34D399" }}>{s.status}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

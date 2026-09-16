"use client";

import React, { useState } from "react";

export default function RadioControlAdminPage() {
  const [activeStation, setActiveStation] = useState("khashia");
  const [isPlaying, setIsPlaying] = useState(true);

  return (
    <div>
      <h1 style={{ fontSize: "1.8rem", fontWeight: 700, marginBottom: "0.5rem" }}>التحكم المباشر في الإذاعات</h1>
      <p style={{ color: "#2E9E9E", marginBottom: "2rem" }}>إدارة مشغل البث (Liquidsoap & Icecast) وتبديل المحطات الحية</p>

      <div style={{ display: "grid", gridTemplateColumns: "2fr 1fr", gap: "1.5rem" }}>
        {/* Main Station Controller */}
        <div style={{ backgroundColor: "#172235", padding: "1.5rem", borderRadius: "12px", border: "1px solid #243B6B" }}>
          <h2 style={{ fontSize: "1.2rem", fontWeight: 600, marginBottom: "1rem" }}>إذاعة التلاوات الخاشعة (البث الرئيسي)</h2>
          
          <div style={{ backgroundColor: "#0E1726", padding: "1rem", borderRadius: "8px", marginBottom: "1.5rem", border: "1px solid #243B6B" }}>
            <div style={{ fontSize: "0.85rem", color: "#2E9E9E" }}>التلاوة الجارية الآن:</div>
            <div style={{ fontSize: "1.1rem", fontWeight: 700, margin: "0.4rem 0" }}>سورة الكهف — الشيخ عبد الباسط عبد الصمد</div>
            <div style={{ fontSize: "0.85rem", color: "#9DAEC6" }}>الترميز: 128 kbps MP3 • معيار الصوت: -16.0 LUFS EBU R128</div>
          </div>

          <div style={{ display: "flex", gap: "1rem" }}>
            <button
              onClick={() => setIsPlaying(!isPlaying)}
              style={{
                backgroundColor: isPlaying ? "#EF4444" : "#10B981",
                color: "#fff",
                border: "none",
                padding: "0.75rem 1.5rem",
                borderRadius: "8px",
                fontWeight: 600,
                cursor: "pointer"
              }}
            >
              {isPlaying ? "⏸️ إيقاف البث مؤقتاً" : "▶️ استئناف البث"}
            </button>
            <button
              onClick={() => alert("تم إرسال أمر تخطي التلاوة إلى Liquidsoap بنجاح.")}
              style={{
                backgroundColor: "#243B6B",
                color: "#fff",
                border: "none",
                padding: "0.75rem 1.5rem",
                borderRadius: "8px",
                fontWeight: 600,
                cursor: "pointer"
              }}
            >
              ⏭️ الانتقال للتلاوة التالية
            </button>
          </div>
        </div>

        {/* Engine Status */}
        <div style={{ backgroundColor: "#172235", padding: "1.5rem", borderRadius: "12px", border: "1px solid #243B6B" }}>
          <h3 style={{ fontSize: "1rem", fontWeight: 600, marginBottom: "1rem", color: "#2E9E9E" }}>حالة محرك البث المركزي</h3>
          <div style={{ display: "flex", flexDirection: "column", gap: "0.8rem", fontSize: "0.85rem" }}>
            <div><strong>حالة Liquidsoap:</strong> <span style={{ color: "#34D399" }}>متصل ونشط (2.2.5)</span></div>
            <div><strong>خوادم Icecast:</strong> <span style={{ color: "#34D399" }}>2 عقد متزامنة</span></div>
            <div><strong>نقطة التعليق (Mount):</strong> <code>/live/khashia.mp3</code></div>
            <div><strong>المستمعون الآن:</strong> 1,420 متصل</div>
            <div><strong>سيرفر Failover:</strong> جاهز للتبديل الفوري</div>
          </div>
        </div>
      </div>
    </div>
  );
}

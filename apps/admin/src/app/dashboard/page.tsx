"use client";

import React from "react";
import { BrandMark } from "@/components/BrandMark";

export default function DashboardOverviewPage() {
  return (
    <div>
      {/* Header */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "2rem" }}>
        <div>
          <h1 style={{ fontSize: "1.8rem", fontWeight: 700 }}>لوحة التحكم والمتابعة</h1>
          <p style={{ color: "#2E9E9E", fontSize: "0.95rem", marginTop: "0.2rem" }}>
            حالة المنظومة — «قرآن يتلى»
          </p>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
          <span style={{
            display: "inline-block",
            width: "10px",
            height: "10px",
            borderRadius: "50%",
            backgroundColor: "#22C55E"
          }} />
          <span style={{ fontSize: "0.85rem", color: "#22C55E", fontWeight: 600 }}>النظام يعمل بصورة ممتازة</span>
        </div>
      </div>

      {/* Metrics Grid */}
      <div style={{
        display: "grid",
        gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",
        gap: "1.2rem",
        marginBottom: "2rem"
      }}>
        <div style={{ backgroundColor: "#172235", padding: "1.5rem", borderRadius: "12px", border: "1px solid #243B6B" }}>
          <span style={{ fontSize: "0.85rem", color: "#9DAEC6" }}>إذاعات البث المباشر</span>
          <div style={{ fontSize: "2rem", fontWeight: 700, color: "#F8F6F1", marginTop: "0.5rem" }}>3</div>
          <span style={{ fontSize: "0.8rem", color: "#2E9E9E" }}>بث مدار 24/7 عبر Icecast</span>
        </div>

        <div style={{ backgroundColor: "#172235", padding: "1.5rem", borderRadius: "12px", border: "1px solid #243B6B" }}>
          <span style={{ fontSize: "0.85rem", color: "#9DAEC6" }}>القراء المعتمدون</span>
          <div style={{ fontSize: "2rem", fontWeight: 700, color: "#F8F6F1", marginTop: "0.5rem" }}>48</div>
          <span style={{ fontSize: "0.8rem", color: "#C77955" }}>بروايات حفص وورش وقالون</span>
        </div>

        <div style={{ backgroundColor: "#172235", padding: "1.5rem", borderRadius: "12px", border: "1px solid #243B6B" }}>
          <span style={{ fontSize: "0.85rem", color: "#9DAEC6" }}>التلاوات المعالجة (-16 LUFS)</span>
          <div style={{ fontSize: "2rem", fontWeight: 700, color: "#F8F6F1", marginTop: "0.5rem" }}>2,840</div>
          <span style={{ fontSize: "0.8rem", color: "#22C55E" }}>مطابقة للمعيار الصوتي الموحد</span>
        </div>

        <div style={{ backgroundColor: "#172235", padding: "1.5rem", borderRadius: "12px", border: "1px solid #243B6B" }}>
          <span style={{ fontSize: "0.85rem", color: "#9DAEC6" }}>المستمعون النشطون الآن</span>
          <div style={{ fontSize: "2rem", fontWeight: 700, color: "#F8F6F1", marginTop: "0.5rem" }}>1,420</div>
          <span style={{ fontSize: "0.8rem", color: "#2E9E9E" }}>عبر تطبيق الجوال والويب</span>
        </div>
      </div>

      {/* Live Radio Engine & Audio Pipeline Panel */}
      <div style={{
        display: "grid",
        gridTemplateColumns: "1fr 1fr",
        gap: "1.5rem"
      }}>
        {/* Radio Status */}
        <div style={{
          backgroundColor: "#172235",
          padding: "1.5rem",
          borderRadius: "12px",
          border: "1px solid #243B6B"
        }}>
          <div style={{ display: "flex", alignItems: "center", gap: "0.75rem", marginBottom: "1rem" }}>
            <BrandMark size={32} isRadio={true} />
            <h3 style={{ fontSize: "1.1rem", fontWeight: 600 }}>إذاعة التلاوات الخاشعة (الرئيسية)</h3>
          </div>
          <div style={{ fontSize: "0.9rem", color: "#9DAEC6", lineHeight: 1.7 }}>
            <div><strong>المسار الصوتي الحالي:</strong> سورة مريم — الشيخ عبد الباسط عبد الصمد</div>
            <div><strong>الجودة:</strong> 128 kbps MP3 Stereo (EBU R128 Compliant)</div>
            <div><strong>المسار التالي:</strong> سورة طه — الشيخ محمد صديق المنشاوي</div>
          </div>
        </div>

        {/* Audio Worker Queue */}
        <div style={{
          backgroundColor: "#172235",
          padding: "1.5rem",
          borderRadius: "12px",
          border: "1px solid #243B6B"
        }}>
          <h3 style={{ fontSize: "1.1rem", fontWeight: 600, marginBottom: "1rem" }}>
            حالة عامل معالجة الصوت (FFmpeg)
          </h3>
          <div style={{ fontSize: "0.9rem", color: "#9DAEC6", lineHeight: 1.7 }}>
            <div><strong>الحالة:</strong> خامل — في انتظار ملفات جديدة</div>
            <div><strong>المهام المكتملة اليوم:</strong> 114 سورة</div>
            <div><strong>معيار التوحيد:</strong> -16.0 LUFS ± 0.5 LU</div>
            <div><strong>استخراج الـ Waveform:</strong> نشط تلقائيًا لكل مسار</div>
          </div>
        </div>
      </div>
    </div>
  );
}

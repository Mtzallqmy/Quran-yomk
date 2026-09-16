"use client";

import React from "react";
import { BrandMark } from "@/components/BrandMark";

export default function IdentityAdminPage() {
  return (
    <div style={{ maxWidth: "800px" }}>
      <h1 style={{ fontSize: "1.8rem", fontWeight: 700, marginBottom: "0.5rem" }}>هوية منصة «قرآن يتلى»</h1>
      <p style={{ color: "#2E9E9E", marginBottom: "2rem" }}>الهوية البصرية واللوائح المعتمدة ومعايير التوزيع السيادي</p>

      <div style={{ backgroundColor: "#172235", padding: "2rem", borderRadius: "16px", border: "1px solid #243B6B", textAlign: "center", marginBottom: "2rem" }}>
        <div style={{ display: "flex", justifyContent: "center", marginBottom: "1rem" }}>
          <BrandMark size={84} />
        </div>
        <h2 style={{ fontSize: "1.8rem", fontWeight: 800, margin: "0 0 0.5rem 0", color: "#F8F6F1" }}>قرآن يتلى</h2>
        <div style={{ color: "#2E9E9E", fontWeight: 600, fontSize: "1rem", marginBottom: "1rem" }}>منصة القرآن الكريم والبث الإذاعي السيادي المدار</div>
        <p style={{ color: "#9DAEC6", fontSize: "0.95rem", lineHeight: "1.6", maxWidth: "600px", margin: "0 auto" }}>
          تطبيق إسلامي مستقل، خالي تماماً من الإعلانات والتتبع التجاري. يعتمد على مجمع الملك فهد لطباعة المصحف الشريف بالمدينة المنورة كمصدر وحيد للنص العثماني، وهندسة الصوت EBU R128 (-16 LUFS) للبث والتسجيلات.
        </p>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "1.5rem" }}>
        <div style={{ backgroundColor: "#172235", padding: "1.5rem", borderRadius: "12px", border: "1px solid #243B6B" }}>
          <h3 style={{ fontSize: "1.1rem", fontWeight: 600, marginBottom: "0.8rem", color: "#2E9E9E" }}>الألوان الأساسية للهوية</h3>
          <div style={{ display: "flex", flexDirection: "column", gap: "0.5rem", fontSize: "0.9rem" }}>
            <div>🔵 <strong>Deep Indigo:</strong> <code>#243B6B</code> (اللون الرئيسي)</div>
            <div>🟢 <strong>Acoustic Teal:</strong> <code>#2E9E9E</code> (الموجات الصوتية والتمييز)</div>
            <div>🟠 <strong>Copper Accent:</strong> <code>#C77955</code> (حامل المصحف الخشبي)</div>
            <div>⚪ <strong>Pearl Background:</strong> <code>#F8F6F1</code> (خلفية الصفحات)</div>
          </div>
        </div>

        <div style={{ backgroundColor: "#172235", padding: "1.5rem", borderRadius: "12px", border: "1px solid #243B6B" }}>
          <h3 style={{ fontSize: "1.1rem", fontWeight: 600, marginBottom: "0.8rem", color: "#2E9E9E" }}>المعلومات القانونية والإصدار</h3>
          <div style={{ display: "flex", flexDirection: "column", gap: "0.5rem", fontSize: "0.9rem" }}>
            <div><strong>الإصدار:</strong> 1.0.0 (Production Candidate)</div>
            <div><strong>حزمة أندرويد:</strong> <code>com.aistudio.quranyutla.live</code></div>
            <div><strong>ترخيص النص:</strong> مجمع الملك فهد (Waqf)</div>
            <div><strong>سياسة الخصوصية:</strong> سيادية وخالية من التتبع 100%</div>
          </div>
        </div>
      </div>
    </div>
  );
}

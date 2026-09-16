"use client";

import React from "react";

export default function ExternalStationsAdminPage() {
  const externalStations = [
    { name: "إذاعة القرآن الكريم من القاهرة", url: "https://stream.ertu.org/quran", rights: "Public Cultural Heritage (ERTU)", status: "متاحة للعميل (Direct Client Play)", provenance: "مفصولة تماماً عن البث المدار الداخلي" },
    { name: "إذاعة نداء الإسلام من مكة المكرمة", url: "https://stream.sba.sa/nedaa", rights: "Official Saudi Broadcasting Authority", status: "متاحة للعميل (Direct Client Play)", provenance: "مفصولة تماماً عن البث المدار الداخلي" },
    { name: "إذاعة القرآن الكريم - الشارقة", url: "https://stream.sba.net.ae/quran", rights: "Sharjah Media Authority", status: "متاحة للعميل (Direct Client Play)", provenance: "مفصولة تماماً عن البث المدار الداخلي" }
  ];

  return (
    <div>
      <h1 style={{ fontSize: "1.8rem", fontWeight: 700, marginBottom: "0.5rem" }}>المحطات الإذاعية الخارجية (Virtual / External)</h1>
      <p style={{ color: "#2E9E9E", marginBottom: "2rem" }}>محطات إذاعية عامة مرخصة يُشغلها العميل مباشرة عبر رابط المصدر، ومفصولة هندسياً وقانونياً عن محرك البث الداخلي</p>

      <div style={{ backgroundColor: "#172235", borderRadius: "12px", border: "1px solid #243B6B", overflow: "hidden" }}>
        <table style={{ width: "100%", borderCollapse: "collapse", textAlign: "right" }}>
          <thead>
            <tr style={{ backgroundColor: "#0E1726", borderBottom: "1px solid #243B6B" }}>
              <th style={{ padding: "1rem" }}>اسم المحطة الخارجية</th>
              <th style={{ padding: "1rem" }}>رابط البث المباشر (Source URL)</th>
              <th style={{ padding: "1rem" }}>التراخيص والحقوق</th>
              <th style={{ padding: "1rem" }}>العزل الهيكلي</th>
              <th style={{ padding: "1rem" }}>الحالة</th>
            </tr>
          </thead>
          <tbody>
            {externalStations.map((st, i) => (
              <tr key={i} style={{ borderBottom: "1px solid #243B6B" }}>
                <td style={{ padding: "1rem", fontWeight: 600 }}>{st.name}</td>
                <td style={{ padding: "1rem", fontFamily: "monospace", color: "#2E9E9E" }}>{st.url}</td>
                <td style={{ padding: "1rem", color: "#C77955" }}>{st.rights}</td>
                <td style={{ padding: "1rem", color: "#9DAEC6", fontSize: "0.85rem" }}>{st.provenance}</td>
                <td style={{ padding: "1rem", color: "#34D399" }}>{st.status}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

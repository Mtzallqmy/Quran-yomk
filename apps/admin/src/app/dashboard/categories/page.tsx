"use client";

import React from "react";

export default function CategoriesAdminPage() {
  const categories = [
    { name: "تلاوات الحرمين الشريفين", slug: "haramain", desc: "تسجيلات صلوات التراويح والتهجد من المسجد الحرام والنبوي", isSystem: true, itemsCount: 420 },
    { name: "المصاحف المرتلة الكاملة", slug: "complete-murattal", desc: "ختمات كاملة برواية حفص عن عاصم لكبار القراء", isSystem: true, itemsCount: 18 },
    { name: "التلاوات الخاشعة والنادرة", slug: "khashia-rare", desc: "تسجيلات إذاعية وتلاوات محافل تاريخية نادرة", isSystem: false, itemsCount: 85 },
    { name: "رواية ورش عن نافع", slug: "warsh", desc: "تلاوات بقراءة أهل المدينة والمغرب العربي", isSystem: false, itemsCount: 6 }
  ];

  return (
    <div>
      <h1 style={{ fontSize: "1.8rem", fontWeight: 700, marginBottom: "0.5rem" }}>التصنيفات والمقامات</h1>
      <p style={{ color: "#2E9E9E", marginBottom: "2rem" }}>إدارة تصنيفات التلاوات مع حماية تصنيفات النظام الأساسية من الحذف العرضي</p>

      <div style={{ backgroundColor: "#172235", borderRadius: "12px", border: "1px solid #243B6B", overflow: "hidden" }}>
        <table style={{ width: "100%", borderCollapse: "collapse", textAlign: "right" }}>
          <thead>
            <tr style={{ backgroundColor: "#0E1726", borderBottom: "1px solid #243B6B" }}>
              <th style={{ padding: "1rem" }}>اسم التصنيف</th>
              <th style={{ padding: "1rem" }}>المعرّف (Slug)</th>
              <th style={{ padding: "1rem" }}>الوصف</th>
              <th style={{ padding: "1rem" }}>عدد المواد</th>
              <th style={{ padding: "1rem" }}>نوع التصنيف</th>
            </tr>
          </thead>
          <tbody>
            {categories.map((c, i) => (
              <tr key={i} style={{ borderBottom: "1px solid #243B6B" }}>
                <td style={{ padding: "1rem", fontWeight: 600 }}>{c.name}</td>
                <td style={{ padding: "1rem", fontFamily: "monospace", color: "#2E9E9E" }}>{c.slug}</td>
                <td style={{ padding: "1rem", color: "#9DAEC6" }}>{c.desc}</td>
                <td style={{ padding: "1rem" }}>{c.itemsCount}</td>
                <td style={{ padding: "1rem" }}>
                  <span style={{
                    padding: "0.25rem 0.6rem",
                    borderRadius: "6px",
                    backgroundColor: c.isSystem ? "#243B6B" : "#374151",
                    fontSize: "0.8rem",
                    color: c.isSystem ? "#60A5FA" : "#D1D5DB"
                  }}>
                    {c.isSystem ? "🔒 نظام أساسي محمي" : "مخصص"}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

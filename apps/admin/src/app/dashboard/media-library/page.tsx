"use client";

import React, { useState } from "react";

export default function MediaLibraryAdminPage() {
  const mediaFiles = [
    { title: "سورة الفاتحة", reciter: "الشيخ عبد الباسط عبد الصمد", size: "2.4 MB", duration: "01:12", lufs: "-16.0", status: "جاهز (Verified)", sha: "e3b0c...855" },
    { title: "سورة الكهف", reciter: "الشيخ محمد صديق المنشاوي", size: "38.5 MB", duration: "42:15", lufs: "-16.1", status: "جاهز (Verified)", sha: "4a21f...39c" },
    { title: "سورة مريم", reciter: "الشيخ محمود خليل الحصري", size: "24.1 MB", duration: "26:40", lufs: "-15.9", status: "جاهز (Verified)", sha: "b890a...11f" },
    { title: "سورة يس", reciter: "الشيخ علي عبد الله جابر", size: "18.2 MB", duration: "19:50", lufs: "قيد المعالجة", status: "Processing", sha: "جاري الحساب" }
  ];

  return (
    <div>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1.5rem" }}>
        <div>
          <h1 style={{ fontSize: "1.8rem", fontWeight: 700, margin: 0 }}>مكتبة الصوت والمعالجة</h1>
          <p style={{ color: "#2E9E9E", marginTop: "0.2rem" }}>التسجيلات المعتمدة والمعالجة بهندسة الصوت EBU R128</p>
        </div>
        <button
          onClick={() => alert("يرجى اختيار ملف MP3 معتمد لرفعه ومعالجته عبر FFmpeg Worker")}
          style={{ backgroundColor: "#2E9E9E", color: "#fff", border: "none", padding: "0.75rem 1.5rem", borderRadius: "8px", fontWeight: 600, cursor: "pointer" }}
        >
          ➕ رفع تلاوة جديدة
        </button>
      </div>

      <div style={{ backgroundColor: "#172235", borderRadius: "12px", border: "1px solid #243B6B", overflow: "hidden" }}>
        <table style={{ width: "100%", borderCollapse: "collapse", textAlign: "right" }}>
          <thead>
            <tr style={{ backgroundColor: "#0E1726", borderBottom: "1px solid #243B6B" }}>
              <th style={{ padding: "1rem" }}>السورة</th>
              <th style={{ padding: "1rem" }}>القارئ</th>
              <th style={{ padding: "1rem" }}>المدة</th>
              <th style={{ padding: "1rem" }}>معيار LUFS</th>
              <th style={{ padding: "1rem" }}>بصمة التشفير (SHA-256)</th>
              <th style={{ padding: "1rem" }}>الحالة</th>
            </tr>
          </thead>
          <tbody>
            {mediaFiles.map((m, i) => (
              <tr key={i} style={{ borderBottom: "1px solid #243B6B" }}>
                <td style={{ padding: "1rem", fontWeight: 600 }}>{m.title}</td>
                <td style={{ padding: "1rem" }}>{m.reciter}</td>
                <td style={{ padding: "1rem", color: "#9DAEC6" }}>{m.duration}</td>
                <td style={{ padding: "1rem", color: "#C77955" }}>{m.lufs}</td>
                <td style={{ padding: "1rem", fontFamily: "monospace", color: "#9DAEC6" }}>{m.sha}</td>
                <td style={{ padding: "1rem", color: m.status.includes("جاهز") ? "#34D399" : "#FBBF24" }}>{m.status}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

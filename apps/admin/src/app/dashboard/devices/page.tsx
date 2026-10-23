"use client";

import React from "react";

export default function DevicesAdminPage() {
  const devices = [
    { id: "inst-9f1a...48c", platform: "Android", version: "1.0.0", locale: "ar", tz: "Asia/Riyadh", consent: "v1.0 (موافق)", lastSeen: "منذ دقيقتين" },
    { id: "inst-b23c...11a", platform: "Android", version: "1.0.0", locale: "ar", tz: "Africa/Cairo", consent: "v1.0 (موافق)", lastSeen: "منذ 15 دقيقة" },
    { id: "inst-74ee...99f", platform: "iOS", version: "1.0.0", locale: "ar", tz: "Asia/Kuwait", consent: "v1.0 (موافق)", lastSeen: "منذ ساعة" },
    { id: "inst-18ca...02d", platform: "Android", version: "0.9.8", locale: "en", tz: "Europe/London", consent: "مُلغى (Revoked)", lastSeen: "منذ 3 أيام" }
  ];

  return (
    <div>
      <h1 style={{ fontSize: "1.8rem", fontWeight: 700, marginBottom: "0.5rem" }}>الأجهزة النشطة والتثبيتات</h1>
      <p style={{ color: "#2E9E9E", marginBottom: "2rem" }}>بيانات الأجهزة المستعارة المجهولة دون تتبع الهويات الشخصية (Zero Surveillance)</p>

      <div style={{ backgroundColor: "#172235", borderRadius: "12px", border: "1px solid #243B6B", overflow: "hidden" }}>
        <table style={{ width: "100%", borderCollapse: "collapse", textAlign: "right" }}>
          <thead>
            <tr style={{ backgroundColor: "#0E1726", borderBottom: "1px solid #243B6B" }}>
              <th style={{ padding: "1rem" }}>معرّف التثبيت المقنّع</th>
              <th style={{ padding: "1rem" }}>المنصة</th>
              <th style={{ padding: "1rem" }}>الإصدار</th>
              <th style={{ padding: "1rem" }}>المنطقة الزمنية</th>
              <th style={{ padding: "1rem" }}>حالة الموافقة</th>
              <th style={{ padding: "1rem" }}>آخر ظهور</th>
            </tr>
          </thead>
          <tbody>
            {devices.map((d, i) => (
              <tr key={i} style={{ borderBottom: "1px solid #243B6B" }}>
                <td style={{ padding: "1rem", fontFamily: "monospace", color: "#9DAEC6" }}>{d.id}</td>
                <td style={{ padding: "1rem" }}>{d.platform}</td>
                <td style={{ padding: "1rem" }}>{d.version}</td>
                <td style={{ padding: "1rem" }}>{d.tz}</td>
                <td style={{ padding: "1rem", color: d.consent.includes("موافق") ? "#34D399" : "#F87171" }}>{d.consent}</td>
                <td style={{ padding: "1rem", color: "#9DAEC6" }}>{d.lastSeen}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

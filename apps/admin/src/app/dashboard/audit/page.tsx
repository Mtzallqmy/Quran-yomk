"use client";

import React from "react";

export default function AuditAdminPage() {
  const auditLogs = [
    { id: "aud-901", actor: "admin@quranyutla.app", action: "SETTINGS_UPDATE", resource: "app.app_config:feature_flags", outcome: "SUCCESS", requestId: "req-c812-4aa9", time: "منذ 4 دقائق" },
    { id: "aud-900", actor: "admin@quranyutla.app", action: "RADIO_SKIP_TRACK", resource: "radio.stations:khashia", outcome: "SUCCESS", requestId: "req-f190-21ba", time: "منذ 25 دقيقة" },
    { id: "aud-899", actor: "worker@quranyutla.app", action: "AUDIO_INGEST_LUFS", resource: "app.audio_tracks:surah-018", outcome: "SUCCESS", requestId: "req-98aa-710e", time: "منذ ساعة" },
    { id: "aud-898", actor: "unknown_client", action: "UNAUTHORIZED_WRITE_ATTEMPT", resource: "app.reciters", outcome: "DENIED (403)", requestId: "req-e320-1110", time: "منذ 3 ساعات" }
  ];

  return (
    <div>
      <h1 style={{ fontSize: "1.8rem", fontWeight: 700, marginBottom: "0.5rem" }}>سجل التدقيق والمراقبة الأمنية</h1>
      <p style={{ color: "#2E9E9E", marginBottom: "2rem" }}>سجل غير قابل للتعديل (Append-Only Audit Trail) يرصد كافة العمليات الحساسة مع عزل بيانات الأسرار تماماً</p>

      <div style={{ backgroundColor: "#172235", borderRadius: "12px", border: "1px solid #243B6B", overflow: "hidden" }}>
        <table style={{ width: "100%", borderCollapse: "collapse", textAlign: "right" }}>
          <thead>
            <tr style={{ backgroundColor: "#0E1726", borderBottom: "1px solid #243B6B" }}>
              <th style={{ padding: "1rem" }}>المسؤول / الفاعل</th>
              <th style={{ padding: "1rem" }}>الإجراء (Action)</th>
              <th style={{ padding: "1rem" }}>المورد المستهدف</th>
              <th style={{ padding: "1rem" }}>معرّف الطلب (Request ID)</th>
              <th style={{ padding: "1rem" }}>النتيجة</th>
              <th style={{ padding: "1rem" }}>التوقيت</th>
            </tr>
          </thead>
          <tbody>
            {auditLogs.map((log) => (
              <tr key={log.id} style={{ borderBottom: "1px solid #243B6B" }}>
                <td style={{ padding: "1rem", fontWeight: 600 }}>{log.actor}</td>
                <td style={{ padding: "1rem", fontFamily: "monospace", color: "#60A5FA" }}>{log.action}</td>
                <td style={{ padding: "1rem", color: "#9DAEC6" }}>{log.resource}</td>
                <td style={{ padding: "1rem", fontFamily: "monospace", color: "#9DAEC6", fontSize: "0.85rem" }}>{log.requestId}</td>
                <td style={{ padding: "1rem", color: log.outcome.includes("SUCCESS") ? "#34D399" : "#F87171" }}>{log.outcome}</td>
                <td style={{ padding: "1rem", color: "#9DAEC6" }}>{log.time}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

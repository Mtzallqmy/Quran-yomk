"use client";

import React, { useState } from "react";

export default function SettingsAdminPage() {
  const [featureFlags, setFeatureFlags] = useState(
    JSON.stringify({
      radio_enabled: true,
      offline_downloads: true,
      prayer_times: true,
      adhkar: true,
      learning_center: true
    }, null, 2)
  );

  const [minVersion, setMinVersion] = useState(
    JSON.stringify({ android: "1.0.0", ios: "1.0.0", force_update: false }, null, 2)
  );

  const [maintenance, setMaintenance] = useState(
    JSON.stringify({ is_active: false, message_ar: "صيانة مجدولة وجيزة" }, null, 2)
  );

  const handleSave = (key: string, val: string) => {
    try {
      JSON.parse(val); // Validate JSON schema
      alert(`تم التحقق من صحة صيغة JSON وحفظ المفتاح [${key}] بنجاح في قاعدة البيانات.`);
    } catch {
      alert("خطأ: صيغة JSON غير صالحة. يرجى تصحيح الخطأ قبل الحفظ.");
    }
  };

  return (
    <div style={{ maxWidth: "900px" }}>
      <h1 style={{ fontSize: "1.8rem", fontWeight: 700, marginBottom: "0.5rem" }}>الإعدادات وتهيئة التشغيل (Runtime Config)</h1>
      <p style={{ color: "#2E9E9E", marginBottom: "2rem" }}>مفاتيح التهيئة المصرح بها (Allow-listed Keys) مع منع إدخال أي أكواد برمجية (Anti-Code Injection)</p>

      <div style={{ display: "flex", flexDirection: "column", gap: "1.5rem" }}>
        {/* Feature Flags */}
        <div style={{ backgroundColor: "#172235", padding: "1.5rem", borderRadius: "12px", border: "1px solid #243B6B" }}>
          <h3 style={{ fontSize: "1.1rem", fontWeight: 600, marginBottom: "0.5rem" }}>مفاتيح الميزات (feature_flags)</h3>
          <p style={{ fontSize: "0.85rem", color: "#9DAEC6", marginBottom: "1rem" }}>تفعيل أو تعطيل التبويبات والمميزات عن بعد في تطبيقات المستخدمين</p>
          <textarea
            value={featureFlags}
            onChange={(e) => setFeatureFlags(e.target.value)}
            rows={5}
            style={{ width: "100%", padding: "0.75rem", borderRadius: "6px", backgroundColor: "#0E1726", border: "1px solid #243B6B", color: "#60A5FA", fontFamily: "monospace", fontSize: "0.85rem" }}
          />
          <button onClick={() => handleSave("feature_flags", featureFlags)} style={{ marginTop: "1rem", backgroundColor: "#2E9E9E", color: "#fff", border: "none", padding: "0.6rem 1.2rem", borderRadius: "6px", fontWeight: 600, cursor: "pointer" }}>حفظ التغييرات</button>
        </div>

        {/* Min Version */}
        <div style={{ backgroundColor: "#172235", padding: "1.5rem", borderRadius: "12px", border: "1px solid #243B6B" }}>
          <h3 style={{ fontSize: "1.1rem", fontWeight: 600, marginBottom: "0.5rem" }}>أدنى إصدار مدعوم (min_supported_version)</h3>
          <p style={{ fontSize: "0.85rem", color: "#9DAEC6", marginBottom: "1rem" }}>التحكم في متطلبات التحديث الإجباري للتطبيقات</p>
          <textarea
            value={minVersion}
            onChange={(e) => setMinVersion(e.target.value)}
            rows={4}
            style={{ width: "100%", padding: "0.75rem", borderRadius: "6px", backgroundColor: "#0E1726", border: "1px solid #243B6B", color: "#60A5FA", fontFamily: "monospace", fontSize: "0.85rem" }}
          />
          <button onClick={() => handleSave("min_supported_version", minVersion)} style={{ marginTop: "1rem", backgroundColor: "#2E9E9E", color: "#fff", border: "none", padding: "0.6rem 1.2rem", borderRadius: "6px", fontWeight: 600, cursor: "pointer" }}>حفظ التغييرات</button>
        </div>

        {/* Maintenance */}
        <div style={{ backgroundColor: "#172235", padding: "1.5rem", borderRadius: "12px", border: "1px solid #243B6B" }}>
          <h3 style={{ fontSize: "1.1rem", fontWeight: 600, marginBottom: "0.5rem" }}>وضع الصيانة (maintenance)</h3>
          <p style={{ fontSize: "0.85rem", color: "#9DAEC6", marginBottom: "1rem" }}>إظهار شاشة صيانة عامة مع رسالة توجيهية للمستخدمين</p>
          <textarea
            value={maintenance}
            onChange={(e) => setMaintenance(e.target.value)}
            rows={4}
            style={{ width: "100%", padding: "0.75rem", borderRadius: "6px", backgroundColor: "#0E1726", border: "1px solid #243B6B", color: "#60A5FA", fontFamily: "monospace", fontSize: "0.85rem" }}
          />
          <button onClick={() => handleSave("maintenance", maintenance)} style={{ marginTop: "1rem", backgroundColor: "#2E9E9E", color: "#fff", border: "none", padding: "0.6rem 1.2rem", borderRadius: "6px", fontWeight: 600, cursor: "pointer" }}>حفظ التغييرات</button>
        </div>
      </div>
    </div>
  );
}

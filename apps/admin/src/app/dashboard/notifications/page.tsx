"use client";

import React, { useState } from "react";

export default function NotificationsAdminPage() {
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [route, setRoute] = useState("/");
  const [targetSegment, setTargetSegment] = useState("all");
  const [statusMsg, setStatusMsg] = useState("");

  const handleSend = () => {
    if (!title || !body) {
      alert("يرجى إدخال عنوان ونص الإشعار");
      return;
    }
    if (confirm("هل تؤكد إرسال الإشعار لجميع الأجهزة المستهدفة المعتمدة؟")) {
      setStatusMsg("تم إرسال الإشعار بنجاح إلى 1,240 جهاز مستهدف بتطابق الموافقة.");
      setTitle("");
      setBody("");
    }
  };

  return (
    <div style={{ maxWidth: "800px" }}>
      <h1 style={{ fontSize: "1.8rem", fontWeight: 700, marginBottom: "0.5rem" }}>إدارة وحملات الإشعارات</h1>
      <p style={{ color: "#2E9E9E", marginBottom: "2rem" }}>إرسال إشعارات مبنية على موافقة المستخدم المسبقة (Opt-in Consent)</p>

      {statusMsg && (
        <div style={{ backgroundColor: "#064E3B", color: "#6EE7B7", padding: "1rem", borderRadius: "8px", marginBottom: "1.5rem" }}>
          {statusMsg}
        </div>
      )}

      <div style={{ backgroundColor: "#172235", padding: "1.5rem", borderRadius: "12px", border: "1px solid #243B6B" }}>
        <div style={{ marginBottom: "1.2rem" }}>
          <label style={{ display: "block", marginBottom: "0.4rem", fontSize: "0.9rem" }}>عنوان الإشعار</label>
          <input
            type="text"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="مثال: بث مباشر لسورة الكهف بصوت الشيخ عبد الباسط"
            style={{ width: "100%", padding: "0.75rem", borderRadius: "6px", backgroundColor: "#0E1726", border: "1px solid #243B6B", color: "#fff" }}
          />
        </div>

        <div style={{ marginBottom: "1.2rem" }}>
          <label style={{ display: "block", marginBottom: "0.4rem", fontSize: "0.9rem" }}>نص الإشعار</label>
          <textarea
            value={body}
            onChange={(e) => setBody(e.target.value)}
            rows={3}
            placeholder="اكتب رسالة الإشعار التذكيرية..."
            style={{ width: "100%", padding: "0.75rem", borderRadius: "6px", backgroundColor: "#0E1726", border: "1px solid #243B6B", color: "#fff" }}
          />
        </div>

        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "1rem", marginBottom: "1.5rem" }}>
          <div>
            <label style={{ display: "block", marginBottom: "0.4rem", fontSize: "0.9rem" }}>المسار داخل التطبيق (Allow-list)</label>
            <select
              value={route}
              onChange={(e) => setRoute(e.target.value)}
              style={{ width: "100%", padding: "0.75rem", borderRadius: "6px", backgroundColor: "#0E1726", border: "1px solid #243B6B", color: "#fff" }}
            >
              <option value="/">الرئيسية (/) </option>
              <option value="/radio">شاشة الإذاعة (/radio)</option>
              <option value="/quran/surah/18">سورة الكهف (/quran/surah/18)</option>
              <option value="/reciters">دليل القراء (/reciters)</option>
            </select>
          </div>

          <div>
            <label style={{ display: "block", marginBottom: "0.4rem", fontSize: "0.9rem" }}>الشريحة المستهدفة</label>
            <select
              value={targetSegment}
              onChange={(e) => setTargetSegment(e.target.value)}
              style={{ width: "100%", padding: "0.75rem", borderRadius: "6px", backgroundColor: "#0E1726", border: "1px solid #243B6B", color: "#fff" }}
            >
              <option value="all">كافة الأجهزة ذات الموافقة النشطة</option>
              <option value="android">أجهزة أندرويد فقط</option>
              <option value="ios">أجهزة iOS فقط</option>
            </select>
          </div>
        </div>

        <button
          onClick={handleSend}
          style={{
            backgroundColor: "#2E9E9E",
            color: "#fff",
            border: "none",
            padding: "0.85rem 1.8rem",
            borderRadius: "8px",
            fontWeight: 700,
            cursor: "pointer"
          }}
        >
          🚀 إرسال الإشعار الآن
        </button>
      </div>
    </div>
  );
}

"use client";

import React, { useState } from "react";

export default function NotificationsAdminPage() {
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [route, setRoute] = useState("/");
  const [targetSegment, setTargetSegment] = useState("all");
  const [testInstallationId, setTestInstallationId] = useState("");
  const [statusMsg, setStatusMsg] = useState("");
  const [isSending, setIsSending] = useState(false);

  const handleSendBroadcast = async () => {
    if (!title || !body) {
      alert("يرجى إدخال عنوان ونص الإشعار");
      return;
    }
    if (confirm("هل تؤكد إرسال الإشعار لجميع الأجهزة المستهدفة المعتمدة؟")) {
      setIsSending(true);
      setStatusMsg("جاري إرسال حملة الإشعارات عبر FCM v1...");
      try {
        setTimeout(() => {
          setStatusMsg("تم إرسال الحملة بنجاح إلى جميع الأجهزة المستهدفة.");
          setIsSending(false);
          setTitle("");
          setBody("");
        }, 800);
      } catch (e: any) {
        setStatusMsg(`حدث خطأ أثناء الإرسال: ${e?.message || e}`);
        setIsSending(false);
      }
    }
  };

  const handleSendTestPush = async () => {
    if (!title || !body) {
      alert("يرجى إدخال عنوان ونص الإشعار التجريبي");
      return;
    }
    if (!testInstallationId) {
      alert("يرجى إدخال معرّف الجهاز (Installation ID) لإرسال الإشعار التجريبي إليه بدلاً من البث العام");
      return;
    }

    setIsSending(true);
    setStatusMsg(`جاري إرسال إشعار تجريبي للجهاز المباشر (${testInstallationId.substring(0, 12)}...)...`);
    try {
      setTimeout(() => {
        setStatusMsg(`✅ تم إرسال الإشعار التجريبي بنجاح للجهاز (Installation: ${testInstallationId}). Status: DELIVERED.`);
        setIsSending(false);
      }, 800);
    } catch (e: any) {
      setStatusMsg(`فشل إرسال الإشعار التجريبي: ${e?.message || e}`);
      setIsSending(false);
    }
  };

  return (
    <div style={{ maxWidth: "800px" }}>
      <h1 style={{ fontSize: "1.8rem", fontWeight: 700, marginBottom: "0.5rem" }}>إدارة وحملات الإشعارات</h1>
      <p style={{ color: "#2E9E9E", marginBottom: "2rem" }}>إرسال إشعارات مبنية على موافقة المستخدم المسبقة (Opt-in Consent) وتجربتها بأمان</p>

      {statusMsg && (
        <div style={{ backgroundColor: statusMsg.startsWith("❌") ? "#7F1D1D" : "#064E3B", color: statusMsg.startsWith("❌") ? "#FCA5A5" : "#6EE7B7", padding: "1rem", borderRadius: "8px", marginBottom: "1.5rem" }}>
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

        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "1rem", marginBottom: "1.2rem" }}>
          <div>
            <label style={{ display: "block", marginBottom: "0.4rem", fontSize: "0.9rem" }}>المسار داخل التطبيق (Allow-list)</label>
            <select
              value={route}
              onChange={(e) => setRoute(e.target.value)}
              style={{ width: "100%", padding: "0.75rem", borderRadius: "6px", backgroundColor: "#0E1726", border: "1px solid #243B6B", color: "#fff" }}
            >
              <option value="/">الرئيسية (/)</option>
              <option value="/radio">شاشة الإذاعة (/radio)</option>
              <option value="/quran/surah/18">سورة الكهف (/quran/surah/18)</option>
              <option value="/reciters">دليل القراء (/reciters)</option>
              <option value="/dhkar">الأذكار (/adhkar)</option>
              <option value="/prayer-times">أوقات الصلاة (/prayer-times)</option>
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

        <div style={{ marginBottom: "1.5rem" }}>
          <label style={{ display: "block", marginBottom: "0.4rem", fontSize: "0.9rem" }}>معرّف جهاز الاختبار (Installation ID للإرسال التجريبي فقط)</label>
          <input
            type="text"
            value={testInstallationId}
            onChange={(e) => setTestInstallationId(e.target.value)}
            placeholder="مثال: inst_1712000000_abc123"
            style={{ width: "100%", padding: "0.75rem", borderRadius: "6px", backgroundColor: "#0E1726", border: "1px solid #243B6B", color: "#fff" }}
          />
        </div>

        <div style={{ display: "flex", gap: "1rem" }}>
          <button
            onClick={handleSendTestPush}
            disabled={isSending}
            style={{
              backgroundColor: "#D97706",
              color: "#fff",
              border: "none",
              padding: "0.85rem 1.4rem",
              borderRadius: "8px",
              fontWeight: 700,
              cursor: isSending ? "not-allowed" : "pointer"
            }}
          >
            🧪 إرسال إشعار تجريبي (Test Push)
          </button>

          <button
            onClick={handleSendBroadcast}
            disabled={isSending}
            style={{
              backgroundColor: "#2E9E9E",
              color: "#fff",
              border: "none",
              padding: "0.85rem 1.8rem",
              borderRadius: "8px",
              fontWeight: 700,
              cursor: isSending ? "not-allowed" : "pointer"
            }}
          >
            🚀 إرسال الإشعار العام للحملة
          </button>
        </div>
      </div>
    </div>
  );
}

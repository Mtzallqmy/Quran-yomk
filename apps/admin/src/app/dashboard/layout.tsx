"use client";

import React, { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { BrandMark } from "@/components/BrandMark";

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const [isDark, setIsDark] = useState(true);
  const pathname = usePathname();

  const navSections = [
    { href: "/dashboard", label: "الرئيسية", icon: "📊" },
    { href: "/dashboard/notifications", label: "الإشعارات", icon: "🔔" },
    { href: "/dashboard/devices", label: "الأجهزة النشطة", icon: "📱" },
    { href: "/dashboard/radio-control", label: "التحكم بالإذاعة", icon: "📻" },
    { href: "/dashboard/media-library", label: "مكتبة الصوت", icon: "🎵" },
    { href: "/dashboard/playlists", label: "قوائم التشغيل", icon: "📑" },
    { href: "/dashboard/schedules", label: "الجداول الزمنية", icon: "🗓️" },
    { href: "/dashboard/reciters", label: "القراء والمسارات", icon: "🎙️" },
    { href: "/dashboard/external-stations", label: "المحطات الخارجية", icon: "🌐" },
    { href: "/dashboard/categories", label: "التصنيفات", icon: "🏷️" },
    { href: "/dashboard/settings", label: "الإعدادات العامة", icon: "⚙️" },
    { href: "/dashboard/audit", label: "سجل التدقيق", icon: "🛡️" },
    { href: "/dashboard/identity", label: "هوية المنتج", icon: "✨" },
  ];

  return (
    <div style={{
      display: "flex",
      minHeight: "100vh",
      backgroundColor: isDark ? "#0E1726" : "#F8F6F1",
      color: isDark ? "#F8F6F1" : "#141C2B",
      direction: "rtl",
      fontFamily: "system-ui, -apple-system, sans-serif"
    }}>
      {/* Sidebar Navigation */}
      <aside style={{
        width: "260px",
        backgroundColor: isDark ? "#172235" : "#FFFFFF",
        borderLeft: `1px solid ${isDark ? "#243B6B" : "#E2E8F0"}`,
        display: "flex",
        flexDirection: "column",
        padding: "1.2rem 1rem",
        height: "100vh",
        position: "sticky",
        top: 0,
        overflowY: "auto"
      }}>
        {/* Brand Header */}
        <div style={{ display: "flex", alignItems: "center", gap: "0.75rem", marginBottom: "1.5rem", padding: "0 0.5rem" }}>
          <BrandMark size={36} />
          <div>
            <h2 style={{ fontSize: "1.1rem", fontWeight: 700, color: "#2E9E9E", margin: 0 }}>قرآن يتلى</h2>
            <span style={{ fontSize: "0.75rem", color: isDark ? "#9DAEC6" : "#5B677A" }}>لوحة الإدارة الموحدة</span>
          </div>
        </div>

        {/* Nav Links */}
        <nav style={{ display: "flex", flexDirection: "column", gap: "0.25rem", flex: 1 }}>
          {navSections.map((item) => {
            const isActive = pathname === item.href;
            return (
              <Link
                key={item.href}
                href={item.href}
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: "0.75rem",
                  padding: "0.6rem 0.8rem",
                  borderRadius: "8px",
                  backgroundColor: isActive ? (isDark ? "#243B6B" : "#EBF2FF") : "transparent",
                  color: isActive ? (isDark ? "#FFFFFF" : "#243B6B") : (isDark ? "#9DAEC6" : "#475569"),
                  textDecoration: "none",
                  fontWeight: isActive ? 600 : 500,
                  fontSize: "0.9rem",
                  transition: "all 0.15s ease"
                }}
              >
                <span>{item.icon}</span>
                <span>{item.label}</span>
              </Link>
            );
          })}
        </nav>

        {/* Theme Toggle & User Info */}
        <div style={{
          paddingTop: "1rem",
          marginTop: "1rem",
          borderTop: `1px solid ${isDark ? "#243B6B" : "#E2E8F0"}`,
          display: "flex",
          flexDirection: "column",
          gap: "0.6rem"
        }}>
          <button
            onClick={() => setIsDark(!isDark)}
            style={{
              padding: "0.5rem",
              borderRadius: "6px",
              border: `1px solid ${isDark ? "#243B6B" : "#CBD5E1"}`,
              backgroundColor: isDark ? "#0E1726" : "#F1F5F9",
              color: isDark ? "#F8F6F1" : "#1E293B",
              cursor: "pointer",
              fontSize: "0.85rem"
            }}
          >
            {isDark ? "☀️ الوضع النهاري" : "🌙 الوضع الليلي"}
          </button>
          <div style={{ fontSize: "0.75rem", color: isDark ? "#9DAEC6" : "#64748B", textAlign: "center" }}>
            admin@quranyutla.app • super_admin
          </div>
        </div>
      </aside>

      {/* Main Content Area */}
      <main style={{ flex: 1, padding: "2rem", overflowY: "auto" }}>
        {children}
      </main>
    </div>
  );
}

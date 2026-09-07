# Tarteel educational content

- Quran text is not duplicated in the educational datasets. The thematic reader consumes the existing `text_uthmani` field verbatim from Tarteel's Quran repository.
- Thematic labels are separate study metadata prepared for Tarteel and referenced to **التفسير الميسر**. The initial source-checked scope is سورة الفاتحة and سورة الإخلاص. It is not a tajweed dataset and must not be presented as one.
- Adhkar references in the bundled baseline are limited to Sahih al-Bukhari, Sahih Muslim, and Jami at-Tirmidhi references recorded per item. No virtue text is added.
- The existing Islamic Library Data cache remains separately attributed in `THIRD_PARTY_CONTENT.md`; its root repository does not provide a blanket license for all resources.

The Quran text must never be generated, normalized, shortened, or rewritten by the learning layer. Hiding words in tests is presentation-only.

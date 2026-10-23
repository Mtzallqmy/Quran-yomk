# infrastructure/icecast

Icecast streaming distribution server container configuration for **Quran Yutla (قرآن يتلى)**.

Provides mount points:
- `/live.mp3`: Primary high-quality 128kbps recitation stream
- `/fallback.mp3`: Loopback local recitations in case of source disconnections

package com.example

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.model.*
import com.example.repository.FirebaseAuthRepository
import com.example.repository.FirestoreRepository
import com.example.repository.QuranYutlaRepository
import com.example.service.PlaybackMode
import com.example.service.QuranYutlaAudioHandler
import com.example.ui.auth.AuthScreen
import com.example.ui.theme.*

class MainActivity : ComponentActivity() {
  private val repository = QuranYutlaRepository()
  private val authRepository = FirebaseAuthRepository()
  private val firestoreRepository = FirestoreRepository()

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    enableEdgeToEdge()
    setContent {
      var isDark by remember { mutableStateOf(false) }
      QuranYutlaTheme(darkTheme = isDark) {
        MainAppScreen(
          repository = repository,
          authRepository = authRepository,
          firestoreRepository = firestoreRepository,
          isDark = isDark,
          onToggleDark = { isDark = !isDark }
        )
      }
    }
  }
}

/**
 * Geometric Brand Mark Composable for Quran Yutla (قرآن يتلى)
 * Features an open Quran on a wooden Rihal stand with an acoustic soundwave recitation arc.
 */
@Composable
fun QuranYutlaBrandMarkComposable(
  modifier: Modifier = Modifier,
  sizeDp: Int = 48,
  isRadio: Boolean = false,
) {
  val primary = DeepIndigoPrimary
  val teal = AcousticTeal
  val copper = CopperAccent
  val pearl = PearlBackground

  Canvas(modifier = modifier.size(sizeDp.dp).testTag("brand_mark")) {
    val w = size.width
    val h = size.height

    // 1. Background Shield
    drawRoundRect(
      color = primary,
      size = Size(w, h),
      cornerRadius = androidx.compose.ui.geometry.CornerRadius(w * 0.22f, h * 0.22f)
    )

    // 2. Recitation Soundwave Arc (Teal)
    val outerArcPath = Path().apply {
      arcTo(
        rect = Rect(
          offset = Offset(w * 0.22f, h * 0.16f),
          size = Size(w * 0.56f, h * 0.56f)
        ),
        startAngleDegrees = 200f,
        sweepAngleDegrees = 140f,
        forceMoveTo = false
      )
    }
    drawPath(
      path = outerArcPath,
      color = teal,
      style = Stroke(width = w * 0.038f, cap = StrokeCap.Round)
    )

    // Inner Recitation Arc (Copper)
    val innerArcPath = Path().apply {
      arcTo(
        rect = Rect(
          offset = Offset(w * 0.32f, h * 0.26f),
          size = Size(w * 0.36f, h * 0.36f)
        ),
        startAngleDegrees = 210f,
        sweepAngleDegrees = 120f,
        forceMoveTo = false
      )
    }
    drawPath(
      path = innerArcPath,
      color = copper,
      style = Stroke(width = w * 0.03f, cap = StrokeCap.Round)
    )

    if (isRadio) {
      val radioPulse = Path().apply {
        arcTo(
          rect = Rect(
            offset = Offset(w * 0.12f, h * 0.06f),
            size = Size(w * 0.76f, h * 0.76f)
          ),
          startAngleDegrees = 200f,
          sweepAngleDegrees = 140f,
          forceMoveTo = false
        )
      }
      drawPath(
        path = radioPulse,
        color = teal.copy(alpha = 0.8f),
        style = Stroke(width = w * 0.024f, cap = StrokeCap.Round)
      )
    }

    // 3. Open Holy Quran Pages
    val leftPage = Path().apply {
      moveTo(w * 0.48f, h * 0.54f)
      quadraticBezierTo(w * 0.38f, h * 0.49f, w * 0.26f, h * 0.53f)
      lineTo(w * 0.26f, h * 0.71f)
      quadraticBezierTo(w * 0.38f, h * 0.67f, w * 0.48f, h * 0.73f)
      close()
    }
    drawPath(path = leftPage, color = pearl)

    val rightPage = Path().apply {
      moveTo(w * 0.52f, h * 0.54f)
      quadraticBezierTo(w * 0.62f, h * 0.49f, w * 0.74f, h * 0.53f)
      lineTo(w * 0.74f, h * 0.71f)
      quadraticBezierTo(w * 0.62f, h * 0.67f, w * 0.52f, h * 0.73f)
      close()
    }
    drawPath(path = rightPage, color = Color.White)

    // 4. Wooden Rihal Stand Base (Copper)
    drawLine(
      color = copper,
      start = Offset(w * 0.38f, h * 0.73f),
      end = Offset(w * 0.62f, h * 0.85f),
      strokeWidth = w * 0.04f,
      cap = StrokeCap.Round
    )
    drawLine(
      color = copper,
      start = Offset(w * 0.62f, h * 0.73f),
      end = Offset(w * 0.38f, h * 0.85f),
      strokeWidth = w * 0.04f,
      cap = StrokeCap.Round
    )
    drawLine(
      color = copper,
      start = Offset(w * 0.30f, h * 0.83f),
      end = Offset(w * 0.70f, h * 0.83f),
      strokeWidth = w * 0.035f,
      cap = StrokeCap.Round
    )

    // 5. Bookmark Ribbon (Teal)
    drawLine(
      color = teal,
      start = Offset(w * 0.50f, h * 0.54f),
      end = Offset(w * 0.50f, h * 0.78f),
      strokeWidth = w * 0.024f,
      cap = StrokeCap.Round
    )
  }
}

data class SurahItem(
  val number: Int,
  val nameAr: String,
  val versesCount: Int,
  val type: String,
  val page: Int
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainAppScreen(
  repository: QuranYutlaRepository,
  authRepository: FirebaseAuthRepository,
  firestoreRepository: FirestoreRepository,
  isDark: Boolean,
  onToggleDark: () -> Unit
) {
  var selectedTab by remember { mutableIntStateOf(0) }
  var showSearchDialog by remember { mutableStateOf(false) }
  var showMushafReader by remember { mutableStateOf<Int?>(null) }
  var showNewPlaylistDialog by remember { mutableStateOf(false) }

  val playbackState by QuranYutlaAudioHandler.state.collectAsState()
  val favorites by repository.favoriteIds.collectAsState()
  val playlists by repository.playlists.collectAsState()
  val downloads by repository.downloads.collectAsState()
  val featureFlags by repository.featureFlags.collectAsState()

  if (showMushafReader != null) {
    MushafReaderView(
      pageNumber = showMushafReader!!,
      onClose = { showMushafReader = null }
    )
    return
  }

  Scaffold(
    modifier = Modifier.fillMaxSize(),
    topBar = {
      TopAppBar(
        title = {
          Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
          ) {
            QuranYutlaBrandMarkComposable(sizeDp = 32, isRadio = true)
            Text("قرآن يتلى", fontWeight = FontWeight.Bold)
          }
        },
        actions = {
          IconButton(onClick = { showSearchDialog = true }) {
            Icon(Icons.Default.Search, contentDescription = "بحث")
          }
          IconButton(onClick = onToggleDark) {
            Icon(
              imageVector = if (isDark) Icons.Default.LightMode else Icons.Default.DarkMode,
              contentDescription = "المظهر"
            )
          }
        }
      )
    },
    bottomBar = {
      Column {
        MiniPlayerBar(playbackState)
        NavigationBar {
          NavigationBarItem(
            selected = selectedTab == 0,
            onClick = { selectedTab = 0 },
            icon = { Icon(Icons.Default.Home, contentDescription = null) },
            label = { Text("الرئيسية") }
          )
          if (featureFlags.radioEnabled) {
            NavigationBarItem(
              selected = selectedTab == 1,
              onClick = { selectedTab = 1 },
              icon = { Icon(Icons.Default.Radio, contentDescription = null) },
              label = { Text("الإذاعة") }
            )
          }
          NavigationBarItem(
            selected = selectedTab == 2,
            onClick = { selectedTab = 2 },
            icon = { Icon(Icons.Default.RecordVoiceOver, contentDescription = null) },
            label = { Text("القراء") }
          )
          NavigationBarItem(
            selected = selectedTab == 3,
            onClick = { selectedTab = 3 },
            icon = { Icon(Icons.Default.Star, contentDescription = null) },
            label = { Text("المفضلة") }
          )
          NavigationBarItem(
            selected = selectedTab == 4,
            onClick = { selectedTab = 4 },
            icon = { Icon(Icons.Default.DownloadDone, contentDescription = null) },
            label = { Text("التنزيلات") }
          )
          NavigationBarItem(
            selected = selectedTab == 5,
            onClick = { selectedTab = 5 },
            icon = { Icon(Icons.Default.PlaylistPlay, contentDescription = null) },
            label = { Text("القوائم") }
          )
          NavigationBarItem(
            selected = selectedTab == 6,
            onClick = { selectedTab = 6 },
            icon = { Icon(Icons.Default.Person, contentDescription = null) },
            label = { Text("الحساب") }
          )
        }
      }
    }
  ) { innerPadding ->
    Box(modifier = Modifier.padding(innerPadding)) {
      when (selectedTab) {
        0 -> QuranHomeTab(
          repository = repository,
          onOpenMushaf = { page -> showMushafReader = page },
          onPlaySurah = { num, name ->
            QuranYutlaAudioHandler.playQuranTrack(
              surahName = name,
              reciterName = "الشيخ عبد الباسط عبد الصمد",
              audioUrl = "https://audio.quranyutla.app/${num.toString().padStart(3, '0')}.mp3"
            )
          },
          onDownloadSurah = { num, name ->
            repository.addDownload(num, name, "الشيخ عبد الباسط عبد الصمد")
          }
        )
        1 -> RadioTab(
          repository = repository,
          playbackState = playbackState,
          favorites = favorites,
          onToggleFavorite = { id -> repository.toggleFavorite(id) }
        )
        2 -> RecitersTab(
          repository = repository,
          favorites = favorites,
          onToggleFavorite = { id -> repository.toggleFavorite(id) },
          onPlayTrack = { sName, rName, url ->
            QuranYutlaAudioHandler.playQuranTrack(sName, rName, url)
          }
        )
        3 -> FavoritesTab(
          repository = repository,
          favorites = favorites,
          onToggleFavorite = { id -> repository.toggleFavorite(id) }
        )
        4 -> DownloadsTab(
          downloads = downloads,
          onPlay = { d ->
            QuranYutlaAudioHandler.playOfflineTrack(d.surahNameAr, d.reciterNameAr, d.localPath ?: "")
          },
          onDelete = { id -> repository.deleteDownload(id) }
        )
        5 -> PlaylistsTab(
          playlists = playlists,
          onCreatePlaylist = { showNewPlaylistDialog = true },
          onDeletePlaylist = { id -> repository.deletePlaylist(id) }
        )
        6 -> AuthScreen(
          authRepository = authRepository,
          firestoreRepository = firestoreRepository,
          onAuthSuccess = { selectedTab = 0 }
        )
      }
    }
  }

  if (showNewPlaylistDialog) {
    var name by remember { mutableStateOf("") }
    AlertDialog(
      onDismissRequest = { showNewPlaylistDialog = false },
      title = { Text("إنشاء قائمة تشغيل جديدة") },
      text = {
        OutlinedTextField(
          value = name,
          onValueChange = { name = it },
          label = { Text("اسم القائمة") }
        )
      },
      confirmButton = {
        TextButton(onClick = {
          if (name.isNotBlank()) {
            repository.createPlaylist(name)
            showNewPlaylistDialog = false
          }
        }) {
          Text("إنشاء")
        }
      },
      dismissButton = {
        TextButton(onClick = { showNewPlaylistDialog = false }) {
          Text("إلغاء")
        }
      }
    )
  }

  if (showSearchDialog) {
    var query by remember { mutableStateOf("") }
    val filteredStations = repository.stations.filter { it.nameAr.contains(query) || it.currentTrack.contains(query) }
    val filteredReciters = repository.reciters.filter { it.nameAr.contains(query) || it.riwaya.contains(query) }

    AlertDialog(
      onDismissRequest = { showSearchDialog = false },
      title = { Text("البحث السريع") },
      text = {
        Column {
          OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            label = { Text("اكتب اسم سورة أو قارئ أو إذاعة") },
            modifier = Modifier.fillMaxWidth()
          )
          Spacer(modifier = Modifier.height(12.dp))
          if (query.isNotBlank()) {
            Text("النتائج: ${filteredStations.size + filteredReciters.size}", fontWeight = FontWeight.Bold)
            filteredStations.forEach { s ->
              TextButton(onClick = {
                QuranYutlaAudioHandler.playRadio(s.nameAr, s.currentTrack, s.streamUrl)
                showSearchDialog = false
              }) {
                Text("محطة: ${s.nameAr}")
              }
            }
            filteredReciters.forEach { r ->
              Text(r.nameAr, color = AcousticTeal, modifier = Modifier.padding(vertical = 4.dp))
            }
          }
        }
      },
      confirmButton = {
        TextButton(onClick = { showSearchDialog = false }) { Text("إغلاق") }
      }
    )
  }
}

@Composable
fun QuranHomeTab(
  repository: QuranYutlaRepository,
  onOpenMushaf: (Int) -> Unit,
  onPlaySurah: (Int, String) -> Unit,
  onDownloadSurah: (Int, String) -> Unit
) {
  val surahs = remember {
    listOf(
      SurahItem(1, "سورة الفاتحة", 7, "مكية", 1),
      SurahItem(2, "سورة البقرة", 286, "مدنية", 2),
      SurahItem(3, "سورة آل عمران", 200, "مدنية", 50),
      SurahItem(18, "سورة الكهف", 110, "مكية", 293),
      SurahItem(36, "سورة يس", 83, "مكية", 440),
      SurahItem(55, "سورة الرحمن", 78, "مدنية", 531),
      SurahItem(67, "سورة الملك", 30, "مكية", 562),
      SurahItem(112, "سورة الإخلاص", 4, "مكية", 604),
      SurahItem(113, "سورة الفلق", 5, "مكية", 604),
      SurahItem(114, "سورة الناس", 6, "مكية", 604)
    )
  }

  LazyColumn(
    modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
    verticalArrangement = Arrangement.spacedBy(14.dp),
    contentPadding = PaddingValues(top = 16.dp, bottom = 24.dp)
  ) {
    // 1. Daily Reading Card
    item {
      Card(
        colors = CardDefaults.cardColors(containerColor = DeepIndigoPrimary),
        shape = RoundedCornerShape(18.dp),
        modifier = Modifier.fillMaxWidth().clickable { onOpenMushaf(293) }
      ) {
        Column(modifier = Modifier.padding(18.dp)) {
          Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
          ) {
            Text("متابعة الورد اليومي", color = AcousticTeal, fontWeight = FontWeight.Bold)
            Icon(Icons.Default.Bookmark, contentDescription = null, tint = CopperAccent)
          }
          Spacer(modifier = Modifier.height(10.dp))
          Text(
            "سورة الكهف — صفحة 293",
            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
            color = Color.White
          )
          Text(
            "آخر قراءة: الآية 10 • الجزء الخامس عشر",
            style = MaterialTheme.typography.bodySmall,
            color = DarkTextSecondary
          )
          Spacer(modifier = Modifier.height(10.dp))
          Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.End,
            verticalAlignment = Alignment.CenterVertically
          ) {
            Text("فتح المصحف", color = AcousticTeal, fontWeight = FontWeight.Bold)
            Spacer(modifier = Modifier.width(4.dp))
            Icon(Icons.Default.ArrowForward, contentDescription = null, tint = AcousticTeal, modifier = Modifier.size(16.dp))
          }
        }
      }
    }

    // 2. Prayer Times Card
    item {
      val pt = repository.prayerTimes
      Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        shape = RoundedCornerShape(16.dp),
        modifier = Modifier.fillMaxWidth()
      ) {
        Column(modifier = Modifier.padding(16.dp)) {
          Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
          ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
              Icon(Icons.Default.AccessTime, contentDescription = null, tint = AcousticTeal, modifier = Modifier.size(18.dp))
              Spacer(modifier = Modifier.width(6.dp))
              Text("مواقيت الصلاة — ${pt.city}", fontWeight = FontWeight.Bold)
            }
            Text("${pt.nextPrayerName} بعد ${pt.nextPrayerRemaining}", color = CopperAccent, fontWeight = FontWeight.Bold, fontSize = 12.sp)
          }
          Spacer(modifier = Modifier.height(12.dp))
          Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceAround
          ) {
            PrayerTimeCol("الفجر", pt.fajr)
            PrayerTimeCol("الظهر", pt.dhuhr)
            PrayerTimeCol("العصر", pt.asr)
            PrayerTimeCol("المغرب", pt.maghrib, isNext = true)
            PrayerTimeCol("العشاء", pt.isha)
          }
        }
      }
    }

    // 3. Surah Index
    item {
      Text(
        text = "فهرس السور القرآنية",
        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold)
      )
    }

    items(surahs) { surah ->
      Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
        shape = RoundedCornerShape(14.dp),
        modifier = Modifier.fillMaxWidth().clickable { onOpenMushaf(surah.page) }
      ) {
        Row(
          modifier = Modifier.padding(14.dp),
          verticalAlignment = Alignment.CenterVertically,
          horizontalArrangement = Arrangement.spacedBy(14.dp)
        ) {
          Box(
            modifier = Modifier
              .size(40.dp)
              .clip(CircleShape)
              .background(DeepIndigoPrimary.copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center
          ) {
            Text(
              text = "${surah.number}",
              style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
              color = DeepIndigoPrimary
            )
          }

          Column(modifier = Modifier.weight(1f)) {
            Text(
              text = surah.nameAr,
              style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
              color = MaterialTheme.colorScheme.onSurface
            )
            Text(
              text = "${surah.versesCount} آية • ${surah.type}",
              style = MaterialTheme.typography.bodySmall,
              color = MaterialTheme.colorScheme.onSurfaceVariant
            )
          }

          IconButton(onClick = { onPlaySurah(surah.number, surah.nameAr) }) {
            Icon(Icons.Default.PlayCircleOutline, contentDescription = "تشغيل", tint = AcousticTeal)
          }

          IconButton(onClick = { onDownloadSurah(surah.number, surah.nameAr) }) {
            Icon(Icons.Default.DownloadForOffline, contentDescription = "تنزيل", tint = CopperAccent)
          }

          Text(
            text = "ص ${surah.page}",
            style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
            color = CopperAccent
          )
        }
      }
    }
  }
}

@Composable
fun PrayerTimeCol(name: String, time: String, isNext: Boolean = false) {
  Column(horizontalAlignment = Alignment.CenterHorizontally) {
    Text(
      text = name,
      fontSize = 12.sp,
      color = if (isNext) AcousticTeal else MaterialTheme.colorScheme.onSurfaceVariant,
      fontWeight = if (isNext) FontWeight.Bold else FontWeight.Normal
    )
    Spacer(modifier = Modifier.height(4.dp))
    Surface(
      color = if (isNext) AcousticTeal.copy(alpha = 0.15f) else Color.Transparent,
      shape = RoundedCornerShape(8.dp)
    ) {
      Text(
        text = time,
        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
        fontWeight = FontWeight.Bold,
        fontSize = 13.sp,
        color = if (isNext) AcousticTeal else MaterialTheme.colorScheme.onSurface
      )
    }
  }
}

@Composable
fun RadioTab(
  repository: QuranYutlaRepository,
  playbackState: com.example.service.PlaybackState,
  favorites: Set<String>,
  onToggleFavorite: (String) -> Unit
) {
  LazyColumn(
    modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
    verticalArrangement = Arrangement.spacedBy(14.dp),
    contentPadding = PaddingValues(top = 16.dp, bottom = 24.dp)
  ) {
    item {
      Card(
        colors = CardDefaults.cardColors(containerColor = DeepIndigoDark),
        shape = RoundedCornerShape(20.dp),
        modifier = Modifier.fillMaxWidth()
      ) {
        Column(
          modifier = Modifier.padding(20.dp),
          horizontalAlignment = Alignment.CenterHorizontally
        ) {
          QuranYutlaBrandMarkComposable(sizeDp = 64, isRadio = true)
          Spacer(modifier = Modifier.height(14.dp))
          Text(
            repository.stations.first().nameAr,
            style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
            color = Color.White
          )
          Spacer(modifier = Modifier.height(6.dp))
          Text(
            "الآن: ${repository.stations.first().currentTrack}",
            color = AcousticTeal,
            style = MaterialTheme.typography.bodyMedium,
            textAlign = TextAlign.Center
          )
          Spacer(modifier = Modifier.height(14.dp))
          Button(
            onClick = {
              val s = repository.stations.first()
              QuranYutlaAudioHandler.playRadio(s.nameAr, s.currentTrack, s.streamUrl)
            },
            colors = ButtonDefaults.buttonColors(containerColor = AcousticTeal),
            shape = RoundedCornerShape(12.dp)
          ) {
            Icon(
              imageVector = if (playbackState.isPlaying && playbackState.currentTitle == repository.stations.first().nameAr)
                Icons.Default.Pause else Icons.Default.PlayArrow,
              contentDescription = null
            )
            Spacer(modifier = Modifier.width(6.dp))
            Text("استمع الآن (128 kbps)")
          }
        }
      }
    }

    item {
      Text(
        "محطات إذاعية أخرى متاحة",
        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold)
      )
    }

    items(repository.stations.drop(1)) { station ->
      val isFav = favorites.contains(station.id)
      Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp)
      ) {
        Row(
          modifier = Modifier.padding(14.dp),
          verticalAlignment = Alignment.CenterVertically,
          horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
          Icon(Icons.Default.Radio, contentDescription = null, tint = AcousticTeal)
          Column(modifier = Modifier.weight(1f)) {
            Text(station.nameAr, fontWeight = FontWeight.Bold)
            Text(station.currentTrack, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
          }
          IconButton(onClick = { onToggleFavorite(station.id) }) {
            Icon(
              if (isFav) Icons.Default.Star else Icons.Default.StarBorder,
              contentDescription = null,
              tint = CopperAccent
            )
          }
          IconButton(onClick = {
            QuranYutlaAudioHandler.playRadio(station.nameAr, station.currentTrack, station.streamUrl)
          }) {
            Icon(Icons.Default.PlayCircleFilled, contentDescription = null, tint = DeepIndigoPrimary, modifier = Modifier.size(32.dp))
          }
        }
      }
    }
  }
}

@Composable
fun RecitersTab(
  repository: QuranYutlaRepository,
  favorites: Set<String>,
  onToggleFavorite: (String) -> Unit,
  onPlayTrack: (String, String, String) -> Unit
) {
  LazyColumn(
    modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
    verticalArrangement = Arrangement.spacedBy(14.dp),
    contentPadding = PaddingValues(top = 16.dp, bottom = 24.dp)
  ) {
    items(repository.reciters) { reciter ->
      val isFav = favorites.contains(reciter.id)
      Card(
        shape = RoundedCornerShape(16.dp),
        modifier = Modifier.fillMaxWidth()
      ) {
        Column(modifier = Modifier.padding(16.dp)) {
          Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp)
          ) {
            Box(
              modifier = Modifier
                .size(48.dp)
                .clip(CircleShape)
                .background(AcousticTeal.copy(alpha = 0.15f)),
              contentAlignment = Alignment.Center
            ) {
              Icon(Icons.Default.Person, contentDescription = null, tint = AcousticTeal)
            }
            Column(modifier = Modifier.weight(1f)) {
              Text(reciter.nameAr, style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold))
              Text(reciter.riwaya, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
              Text("${reciter.surahsCount} سورة • ${reciter.audioQuality}", color = CopperAccent, fontSize = 12.sp, fontWeight = FontWeight.Bold)
            }
            IconButton(onClick = { onToggleFavorite(reciter.id) }) {
              Icon(if (isFav) Icons.Default.Star else Icons.Default.StarBorder, contentDescription = null, tint = CopperAccent)
            }
          }
          Spacer(modifier = Modifier.height(10.dp))
          Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.End
          ) {
            Button(
              onClick = {
                onPlayTrack("سورة الكهف", reciter.nameAr, "https://audio.quranyutla.app/018.mp3")
              },
              colors = ButtonDefaults.buttonColors(containerColor = DeepIndigoPrimary),
              shape = RoundedCornerShape(10.dp)
            ) {
              Icon(Icons.Default.PlayArrow, contentDescription = null, modifier = Modifier.size(16.dp))
              Spacer(modifier = Modifier.width(4.dp))
              Text("تشغيل تلاوة عينة")
            }
          }
        }
      }
    }
  }
}

@Composable
fun FavoritesTab(
  repository: QuranYutlaRepository,
  favorites: Set<String>,
  onToggleFavorite: (String) -> Unit
) {
  val favStations = repository.stations.filter { favorites.contains(it.id) }
  val favReciters = repository.reciters.filter { favorites.contains(it.id) }

  LazyColumn(
    modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
    verticalArrangement = Arrangement.spacedBy(14.dp),
    contentPadding = PaddingValues(top = 16.dp, bottom = 24.dp)
  ) {
    item {
      Text("المحطات المفضلة (${favStations.size})", fontWeight = FontWeight.Bold)
    }
    items(favStations) { s ->
      Card(shape = RoundedCornerShape(14.dp)) {
        Row(
          modifier = Modifier.padding(14.dp),
          verticalAlignment = Alignment.CenterVertically
        ) {
          Icon(Icons.Default.Radio, contentDescription = null, tint = AcousticTeal)
          Spacer(modifier = Modifier.width(12.dp))
          Column(modifier = Modifier.weight(1f)) {
            Text(s.nameAr, fontWeight = FontWeight.Bold)
            Text(s.currentTrack, style = MaterialTheme.typography.bodySmall)
          }
          IconButton(onClick = { onToggleFavorite(s.id) }) {
            Icon(Icons.Default.Star, contentDescription = null, tint = CopperAccent)
          }
        }
      }
    }

    item {
      Spacer(modifier = Modifier.height(8.dp))
      Text("القراء المفضلون (${favReciters.size})", fontWeight = FontWeight.Bold)
    }
    items(favReciters) { r ->
      Card(shape = RoundedCornerShape(14.dp)) {
        Row(
          modifier = Modifier.padding(14.dp),
          verticalAlignment = Alignment.CenterVertically
        ) {
          Icon(Icons.Default.Person, contentDescription = null, tint = AcousticTeal)
          Spacer(modifier = Modifier.width(12.dp))
          Column(modifier = Modifier.weight(1f)) {
            Text(r.nameAr, fontWeight = FontWeight.Bold)
            Text(r.riwaya, style = MaterialTheme.typography.bodySmall)
          }
          IconButton(onClick = { onToggleFavorite(r.id) }) {
            Icon(Icons.Default.Star, contentDescription = null, tint = CopperAccent)
          }
        }
      }
    }
  }
}

@Composable
fun DownloadsTab(
  downloads: List<DownloadTask>,
  onPlay: (DownloadTask) -> Unit,
  onDelete: (String) -> Unit
) {
  LazyColumn(
    modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
    verticalArrangement = Arrangement.spacedBy(14.dp),
    contentPadding = PaddingValues(top = 16.dp, bottom = 24.dp)
  ) {
    items(downloads) { d ->
      val isCompleted = d.status == DownloadStatus.COMPLETED
      Card(shape = RoundedCornerShape(16.dp)) {
        Column(modifier = Modifier.padding(16.dp)) {
          Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
          ) {
            Text(d.surahNameAr, fontWeight = FontWeight.Bold, fontSize = 16.sp)
            Surface(
              color = if (isCompleted) AcousticTeal.copy(alpha = 0.15f) else CopperAccent.copy(alpha = 0.15f),
              shape = RoundedCornerShape(8.dp)
            ) {
              Text(
                text = if (isCompleted) "موثق (SHA-256)" else "تحميل ${d.progressPercent}%",
                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                color = if (isCompleted) AcousticTeal else CopperAccent,
                fontWeight = FontWeight.Bold,
                fontSize = 11.sp
              )
            }
          }
          Text(d.reciterNameAr, color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 13.sp)
          Spacer(modifier = Modifier.height(10.dp))
          if (isCompleted) {
            Row(
              modifier = Modifier.fillMaxWidth(),
              horizontalArrangement = Arrangement.SpaceBetween,
              verticalAlignment = Alignment.CenterVertically
            ) {
              Text("الحجم: 28.4 MB • تشغيل محلي", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
              Row {
                IconButton(onClick = { onPlay(d) }) {
                  Icon(Icons.Default.PlayArrow, contentDescription = null, tint = AcousticTeal)
                }
                IconButton(onClick = { onDelete(d.id) }) {
                  Icon(Icons.Default.Delete, contentDescription = null, tint = Color.Red.copy(alpha = 0.7f))
                }
              }
            }
          } else {
            LinearProgressIndicator(
              progress = { d.progressPercent / 100f },
              modifier = Modifier.fillMaxWidth().height(4.dp),
              color = AcousticTeal
            )
          }
        }
      }
    }
  }
}

@Composable
fun PlaylistsTab(
  playlists: List<Playlist>,
  onCreatePlaylist: () -> Unit,
  onDeletePlaylist: (String) -> Unit
) {
  LazyColumn(
    modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
    verticalArrangement = Arrangement.spacedBy(14.dp),
    contentPadding = PaddingValues(top = 16.dp, bottom = 24.dp)
  ) {
    item {
      Button(
        onClick = onCreatePlaylist,
        colors = ButtonDefaults.buttonColors(containerColor = AcousticTeal),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth()
      ) {
        Icon(Icons.Default.Add, contentDescription = null)
        Spacer(modifier = Modifier.width(6.dp))
        Text("إنشاء قائمة تشغيل جديدة")
      }
    }

    items(playlists) { pl ->
      Card(shape = RoundedCornerShape(14.dp)) {
        Column(modifier = Modifier.padding(16.dp)) {
          Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
          ) {
            Text(pl.name, fontWeight = FontWeight.Bold, fontSize = 16.sp)
            IconButton(onClick = { onDeletePlaylist(pl.id) }) {
              Icon(Icons.Default.DeleteOutline, contentDescription = null, tint = Color.Red)
            }
          }
          Text("${pl.items.size} تلاوات في القائمة", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
          pl.items.forEach { item ->
            ListItem(
              headlineContent = { Text(item.title, fontWeight = FontWeight.SemiBold) },
              supportingContent = { Text(item.subtitle) },
              trailingContent = {
                IconButton(onClick = {
                  QuranYutlaAudioHandler.playQuranTrack(item.title, item.subtitle, item.audioUrl)
                }) {
                  Icon(Icons.Default.PlayArrow, contentDescription = null, tint = AcousticTeal)
                }
              }
            )
          }
        }
      }
    }
  }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MushafReaderView(
  pageNumber: Int,
  onClose: () -> Unit
) {
  var currentPage by remember { mutableIntStateOf(pageNumber) }

  Scaffold(
    topBar = {
      TopAppBar(
        title = { Text("صفحة $currentPage من 604") },
        navigationIcon = {
          IconButton(onClick = onClose) {
            Icon(Icons.Default.Close, contentDescription = "إغلاق")
          }
        }
      )
    },
    bottomBar = {
      Surface(color = DeepIndigoDark) {
        Row(
          modifier = Modifier.fillMaxWidth().padding(16.dp),
          horizontalArrangement = Arrangement.SpaceBetween,
          verticalAlignment = Alignment.CenterVertically
        ) {
          IconButton(
            onClick = { if (currentPage > 1) currentPage-- },
            enabled = currentPage > 1
          ) {
            Icon(Icons.Default.ArrowForward, contentDescription = null, tint = Color.White)
          }
          Text("الصفحة $currentPage من 604", color = Color.White, fontWeight = FontWeight.Bold)
          IconButton(
            onClick = { if (currentPage < 604) currentPage++ },
            enabled = currentPage < 604
          ) {
            Icon(Icons.Default.ArrowBack, contentDescription = null, tint = Color.White)
          }
        }
      }
    }
  ) { padding ->
    Box(
      modifier = Modifier
        .fillMaxSize()
        .padding(padding)
        .background(PearlBackground)
        .padding(20.dp),
      contentAlignment = Alignment.Center
    ) {
      Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp),
        modifier = Modifier.fillMaxWidth()
      ) {
        Column(
          modifier = Modifier.padding(20.dp),
          horizontalAlignment = Alignment.CenterHorizontally
        ) {
          Surface(
            color = DeepIndigoPrimary.copy(alpha = 0.08f),
            shape = RoundedCornerShape(8.dp),
            modifier = Modifier.fillMaxWidth()
          ) {
            Row(
              modifier = Modifier.padding(8.dp),
              horizontalArrangement = Arrangement.SpaceBetween
            ) {
              Text("الجزء 15", fontSize = 12.sp, fontWeight = FontWeight.Bold)
              Text("سُورَةُ الكَهْفِ", fontSize = 14.sp, fontWeight = FontWeight.Bold, color = DeepIndigoPrimary)
              Text("الحزب 29", fontSize = 12.sp, fontWeight = FontWeight.Bold)
            }
          }
          Spacer(modifier = Modifier.height(16.dp))
          Text(
            "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
            fontWeight = FontWeight.Bold,
            fontSize = 18.sp,
            color = DeepIndigoPrimary
          )
          Spacer(modifier = Modifier.height(16.dp))
          Text(
            "الْحَمْدُ لِلَّهِ الَّذِي أَنزَلَ عَلَىٰ عَبْدِهِ الْكِتَابَ وَلَمْ يَجْعَل لَّهُ عِوَجًا ﴿١﴾ قَيِّمًا لِّيُنذِرَ بَأْسًا شَدِيدًا مِّن لَّدُنْهُ وَيُبَشِّرَ الْمُؤْمِنِينَ الَّذِينَ يَعْمَلُونَ الصَّالِحَاتِ أَنَّ لَهُمْ أَجْرًا حَسَنًا ﴿٢﴾ مَّاكِثِينَ فِيهِ أَبَدًا ﴿٣﴾ وَيُنذِرَ الَّذِينَ قَالُوا اتَّخَذَ اللَّهُ وَلَدًا ﴿٤﴾",
            fontSize = 18.sp,
            lineHeight = 36.sp,
            textAlign = TextAlign.Justify,
            color = DarkTextPrimary
          )
        }
      }
    }
  }
}

/**
 * Bottom Mini Audio Player Bar
 */
@Composable
fun MiniPlayerBar(playbackState: com.example.service.PlaybackState) {
  Surface(
    color = DeepIndigoDark,
    shadowElevation = 8.dp,
    modifier = Modifier.fillMaxWidth().testTag("mini_player_bar")
  ) {
    Column {
      LinearProgressIndicator(
        progress = { 0.42f },
        modifier = Modifier.fillMaxWidth().height(3.dp),
        color = AcousticTeal,
        trackColor = DeepIndigoPrimary,
      )
      Row(
        modifier = Modifier
          .fillMaxWidth()
          .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
      ) {
        QuranYutlaBrandMarkComposable(sizeDp = 34, isRadio = playbackState.mode == PlaybackMode.RADIO)
        Column(modifier = Modifier.weight(1f)) {
          Text(
            text = playbackState.currentTitle,
            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
            color = Color.White,
            maxLines = 1
          )
          Text(
            text = playbackState.currentSubtitle,
            style = MaterialTheme.typography.bodySmall,
            color = AcousticTeal,
            maxLines = 1
          )
        }
        IconButton(onClick = { QuranYutlaAudioHandler.togglePlayPause() }) {
          Icon(
            imageVector = if (playbackState.isPlaying) Icons.Default.PauseCircle else Icons.Default.PlayCircle,
            contentDescription = "تشغيل/إيقاف",
            tint = AcousticTeal,
            modifier = Modifier.size(34.dp)
          )
        }
      }
    }
  }
}

/**
 * Retained for backward screenshot test compatibility
 */
@Composable
fun Greeting(name: String, modifier: Modifier = Modifier) {
  Text(text = "قرآن يتلى — $name", modifier = modifier)
}

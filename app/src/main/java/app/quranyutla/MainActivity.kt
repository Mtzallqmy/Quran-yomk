package app.quranyutla

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import app.quranyutla.ui.MainAppScreen
import app.quranyutla.ui.theme.QuranYutlaTheme
import app.quranyutla.viewmodel.MainViewModel

class MainActivity : ComponentActivity() {
    private val viewModel: MainViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            var isDark by remember { mutableStateOf(false) }
            QuranYutlaTheme(darkTheme = isDark) {
                MainAppScreen(
                    viewModel = viewModel,
                    isDark = isDark,
                    onToggleDark = { isDark = !isDark }
                )
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

import 'app.dart';
import 'features/game/application/game_session_coordinator.dart';
import 'features/game/data/daily_catalog.dart';
import 'features/game/data/game_data.dart';
import 'features/game/data/progress_repository.dart';
import 'main.dart' show runWordGame;

Future<void> main() => runWordGame(const WordGameApp(loader: _loadPreview));

Future<GameSessionCoordinator> _loadPreview() async {
  final data = await GameData.load(version: 3);
  final daily = await DailyCatalog.load();
  final repository = await SqliteProgressRepository.open();
  try {
    return await GameSessionCoordinator.create(
      data,
      repository,
      dailyCatalog: daily,
    );
  } catch (_) {
    await repository.close();
    rethrow;
  }
}

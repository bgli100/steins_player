
import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { SaveFileBridge } from '../savefile/SaveFileBridge';
import { window } from '@kit.ArkUI';

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    SaveFileBridge.attach(flutterEngine, this.context)
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    super.onWindowStageCreate(windowStage);
    const mainWindow = windowStage.getMainWindowSync();
    mainWindow.setWindowLayoutFullScreen(true);
    mainWindow.setWindowSystemBarEnable([]);
    mainWindow.setPreferredOrientation(window.Orientation.AUTO_ROTATION_LANDSCAPE);
  }
}

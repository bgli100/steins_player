import { FlutterEngine, Log, MethodCall, MethodChannel, MethodCallHandler, MethodResult } from '@ohos/flutter_ohos';
import { picker } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';

const TAG = 'SaveFileHandler';
const CHANNEL_NAME = 'lullaby/save_file';

/**
 * Saves game data through the system file picker.
 *
 * `file_picker`'s HarmonyOS implementation drops the payload of `save()`, so the
 * picker is driven here instead: pick a location, then write the bytes.
 */
class SaveFileHandler implements MethodCallHandler {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method !== 'save') {
      result.notImplemented();
      return;
    }
    const args = call.args as Map<string, Object>;
    const fileName = args.get('fileName') as string;
    const bytes = args.get('bytes') as Uint8Array;

    const options = new picker.DocumentSaveOptions();
    options.newFileNames = [fileName];
    const documentPicker = new picker.DocumentViewPicker(this.context);

    documentPicker.save(options).then((uris: Array<string>) => {
      if (uris == null || uris.length == 0) {
        result.success(null);
        return;
      }
      const uri = uris[0];
      try {
        const file = fs.openSync(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
        fs.writeSync(file.fd, bytes.buffer);
        fs.closeSync(file);
        Log.i(TAG, `saved ${bytes.length} bytes to ${uri}`);
        result.success(uri);
      } catch (error) {
        const err = error as BusinessError;
        Log.e(TAG, `write failed: ${err.code} ${err.message}`);
        result.error('save_failed', err.message, null);
      }
    }).catch((error: BusinessError) => {
      // The picker reports a cancelled selection as an error as well.
      Log.w(TAG, `picker closed: ${error.code} ${error.message}`);
      result.success(null);
    });
  }
}

export class SaveFileBridge {
  static attach(engine: FlutterEngine, context: common.UIAbilityContext): void {
    const channel = new MethodChannel(engine.dartExecutor.getBinaryMessenger(), CHANNEL_NAME);
    channel.setMethodCallHandler(new SaveFileHandler(context));
  }
}

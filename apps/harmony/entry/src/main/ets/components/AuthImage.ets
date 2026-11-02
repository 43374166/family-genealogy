import { image } from '@kit.ImageKit';
import { AppServices } from '../service/ApiClient';

@Component
export struct AuthImage {
  @Prop @Watch('onPathChanged') path: string = '';
  @Prop radius: number = 10;
  @Prop fit: ImageFit = ImageFit.Cover;
  @State private pixelMap: image.PixelMap | undefined = undefined;
  @State private failed: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  private onPathChanged(): void {
    if (this.pixelMap !== undefined) {
      this.pixelMap.release();
      this.pixelMap = undefined;
    }
    this.failed = false;
    this.load();
  }

  aboutToDisappear(): void {
    if (this.pixelMap !== undefined) {
      this.pixelMap.release();
      this.pixelMap = undefined;
    }
  }

  private async load(): Promise<void> {
    if (this.path.length === 0) {
      this.failed = true;
      return;
    }
    try {
      const buffer = await AppServices.api.bytes(this.path);
      const source = image.createImageSource(buffer);
      const pixelMap = await source.createPixelMap();
      source.release();
      if (pixelMap !== undefined) {
        this.pixelMap = pixelMap;
      } else {
        this.failed = true;
      }
    } catch (_) {
      this.failed = true;
    }
  }

  build() {
    Stack() {
      if (this.pixelMap !== undefined) {
        Image(this.pixelMap)
          .width('100%')
          .height('100%')
          .objectFit(this.fit)
      } else {
        Column({ space: 3 }) {
          Text(this.failed ? '图' : '…')
            .fontSize(18)
            .fontColor('#89969C')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#EDF2F5')
      }
    }
    .width('100%')
    .height('100%')
    .borderRadius(this.radius)
    .clip(true)
  }
}

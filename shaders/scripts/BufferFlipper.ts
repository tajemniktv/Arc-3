export class BufferFlipper {
    isAlt: boolean
    textureA: BuiltTexture;
    textureB: BuiltTexture;

    constructor(textureA: BuiltTexture, textureB: BuiltTexture) {
        this.textureA = textureA;
        this.textureB = textureB;
        this.isAlt = false;
    }

    flip(): void {
        this.isAlt = !this.isAlt;
    }

    getReadTextureName(): string {
        return this.isAlt ? this.textureA.name() : this.textureB.name();
    }

    getReadImageName(): string {
        return this.isAlt ? this.textureA.imageName() : this.textureB.imageName();
    }

    getWriteImageName(): string {
        return this.isAlt ? this.textureB.imageName() : this.textureA.imageName();
    }

    getReadTexture(): BuiltTexture {
        return this.isAlt ? this.textureA : this.textureB;
    }

    getWriteTexture(): BuiltTexture {
        return this.isAlt ? this.textureB : this.textureA;
    }
}

export class FloodFill {
    private texFloodFillA: BuiltTexture;
    private texFloodFillB: BuiltTexture;
    private texFloodFill_read: ActiveTextureReference;
    private imgFloodFill_write: ActiveTextureReference;

    
    constructor(pipeline: PipelineConfig, size: number) {
        this.texFloodFillA = pipeline.createImageTexture('texFloodFillA', 'imgFloodFillA')
            .format(Format.RGBA16F)
            .width(size)
            .height(size)
            .depth(size)
            .clear(false)
            .build();

        this.texFloodFillB = pipeline.createImageTexture('texFloodFillB', 'imgFloodFillB')
            .format(Format.RGBA16F)
            .width(size)
            .height(size)
            .depth(size)
            .clear(false)
            .build();

        this.texFloodFill_read = pipeline.createTextureReference('texFloodFill_read', 'imgFloodFill_read', size, size, size, Format.RGBA16F);
        this.imgFloodFill_write = pipeline.createTextureReference('texFloodFill_write', 'imgFloodFill_write', size, size, size, Format.RGBA16F);
    }

    create(stage: CommandList, size: number) {
        stage.createCompute("floodfill")
            .location("pre/floodfill", "floodfill")
            .workGroups(
                Math.ceil(size / 8),
                Math.ceil(size / 8),
                Math.ceil(size / 8))
            .compile();
    }

    update(altFrame: boolean) {
        this.texFloodFill_read.pointTo(altFrame ? this.texFloodFillA : this.texFloodFillB);
        this.imgFloodFill_write.pointTo(altFrame ? this.texFloodFillB : this.texFloodFillA);
    }
}

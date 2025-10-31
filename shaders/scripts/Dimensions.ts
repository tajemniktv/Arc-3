export class Dimensions {
    Index: number;
    World_HasSky: boolean;

    constructor(config: RendererConfig) {
        this.World_HasSky = false;

        switch (config.dimension.getPath()) {
            case 'the_nether':
                this.Index = -1;
                break;
            case 'the_end':
                this.Index = 1;
                this.World_HasSky = true;
                break;
            default:
                this.Index = 0;
                this.World_HasSky = true;
                break;
        }
    }
}

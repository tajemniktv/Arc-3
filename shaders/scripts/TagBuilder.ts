export class TagBuilder {
    pipeline : PipelineConfig;
    index: number = 0;

    constructor(pipeline : PipelineConfig) {
        this.pipeline = pipeline;
    }

    map(name: string, namespace: NamespacedId): TagBuilder {
        if (this.index >= 32) throw new RangeError('Limit of 32 tags has been exceeded!');

        this.pipeline.addTag(this.index, namespace);
        defineGlobally(name, this.index);
        this.index++;

        return this;
    }
}

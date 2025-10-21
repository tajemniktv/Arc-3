import aperture;
import buffers.scene;

extern static const bool EnableTAA;
extern static const bool disableFog;

ConstantBuffer<SceneBuffer> ssboScene;

struct VertexOutput {
    // The value after the colon is known as a "semantic", and denotes a special value used by the graphics pipeline.
    // There are many of these usable in both vertex and fragment, but in this case, SV_Position is all we care about; it is equivalent to writing gl_Position.
    float4 position : SV_Position;
    float2 uv;
    float4 color;
    float2 light;
    float distance;
};

[[shader("vertex")]]
VertexOutput vertexMain(Vertex input) { // If we had any more vertex semantics we wanted to use, we could declare them after input in the parameters.
    VertexOutput output;

    // The Vertex struct has many built in variables. Some of them are declared as Optional types, meaning they may not be present
    // depending on the object.

    // Basic transformations.
    float4 modelPos = input.pos(); // These functions are capable of running expensive calculations; better to cache when possible.

    output.position = mul(input.projectionMatrix(), mul(input.viewMatrix(), modelPos));
    output.uv = input.uv();
    output.color = input.color();
    output.light = input.light();
    output.distance = length(modelPos);

    // There is... one more thing we should deal with. When an entity gets hit and turns red, this is known as an "overlay color"; and that is a manual job.
    // Overlay color is one of the mentioned Optional semantics; we can check if it exists and apply it if so.
    
    //float4 overlayColor = input.overlayColor().orElse(float4(0.0));
    // orElse is one way to handle an optional, but there is another way. The following allows you to auto-check the existence of an optional.

    if (let overlayColor = input.overlayColor()) {
        output.color = lerp(output.color, overlayColor, overlayColor.a);
    }

    if (EnableTAA) {
        output.position.xy += 2.0 * ssboScene.taa_jitter * output.position.w;
    }

    return output;
}


struct FragmentOutput {
    float4 color : SV_Target0;
    float2 velocity : SV_Target1;
};

// The fragment entrypoint takes the output of the vertex shader as input.
[[shader("fragment")]]
FragmentOutput fragmentMain(VertexOutput input) { // See the comment in gamma.slang about what targets are.
    // Aperture provides some built-in samplers for object shaders.
    float4 color = albedoTex.Sample(input.uv) * input.color;

    color.rgb *= lightmap.Sample(input.light).rgb;

    iris_discardIfNeeded(color); // This helper function is given by Aperture to auto-discard if needed in the object shader.

    // Apply fog if needed
    if (!disableFog) {
        float mixValue = (input.distance - ap.world.fogStart) / (ap.world.fogEnd - ap.world.fogStart);

        float renderDistanceFogStart = clamp(ap.world.renderDistance / 10, 4, 64); // Default calculation as of 1.21.10.
        mixValue = max(mixValue, (input.distance - renderDistanceFogStart) / (ap.world.renderDistance - renderDistanceFogStart));

        color = lerp(color, ap.world.fogColor, clamp(mixValue, 0.0, 1.0));
    }

    FragmentOutput output;
    output.color = color;
    output.velocity = float2(0.0);

    return output;
}

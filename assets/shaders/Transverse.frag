#pragma header
uniform vec2 iResolution;

int sampleCount = 50;
float blur = 0.25;
float falloff = 7.0;

void main()
{
    vec2 fragCoord = openfl_TextureCoordv * iResolution;
    vec2 uv = openfl_TextureCoordv;
    vec2 destCoord = openfl_TextureCoordv;

    vec2 direction = normalize(destCoord - 0.5);
    vec2 velocity = direction * blur * pow(length(destCoord - 0.5), falloff);
    float inverseSampleCount = 1.0 / float(sampleCount);

    vec2 incR = velocity * 1.0 * inverseSampleCount;
    vec2 incG = velocity * 2.0 * inverseSampleCount;
    vec2 incB = velocity * 4.0 * inverseSampleCount;

    vec3 accumulator = vec3(0.0);
    vec2 offR = vec2(0.0);
    vec2 offG = vec2(0.0);
    vec2 offB = vec2(0.0);

    for (int i = 0; i < sampleCount; i++) {
        accumulator.r += texture2D(bitmap, destCoord + offR).r;
        accumulator.g += texture2D(bitmap, destCoord + offG).g;
        accumulator.b += texture2D(bitmap, destCoord + offB).b;

        offR -= incR;
        offG -= incG;
        offB -= incB;
    }

    gl_FragColor = vec4(accumulator / float(sampleCount), 1.0);
}
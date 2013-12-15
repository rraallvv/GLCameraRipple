
precision mediump float;

uniform sampler2D texture0;
uniform sampler2D texture1;

varying vec2 texCoordVarying;

void main()
{
    gl_FragColor = texture2D(texture1, texCoordVarying) + texture2D(texture0, texCoordVarying);
}

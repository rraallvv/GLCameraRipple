
precision mediump float;

uniform sampler2D texture0;
uniform sampler2D texture1;

varying vec2 texCoordVarying;

void main()
{
	/*
	vec4 color = texture2D(texture1, texCoordVarying);
	float alpha = (1.0 - color.b * 0.5)*step(0.5, color.b);
    gl_FragColor = texture2D(texture0, texCoordVarying)*(1.0-alpha) + color*alpha*vec4(0.3,0.5,1.0,1.0);
	*/
    gl_FragColor = texture2D(texture0, texCoordVarying);
}

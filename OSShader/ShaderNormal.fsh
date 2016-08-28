precision mediump float;//mediump
varying  vec2 texCoordVarying;
uniform sampler2D sam2DY;
uniform sampler2D sam2DUV;
void main(){
    mediump vec3 yuv;
    lowp vec3 rgb;
    mediump mat3 convert = mat3(1.164,  1.164, 1.164,
                                0.0, -0.213, 2.112,
                                1.793, -0.533,   0.0);
    yuv.x = texture2D(sam2DY,texCoordVarying).r - (16.0/255.0);
    yuv.yz = texture2D(sam2DUV,texCoordVarying).rg - vec2(0.5, 0.5);
    rgb = convert*yuv;
    gl_FragColor = vec4(rgb,1);
    
}
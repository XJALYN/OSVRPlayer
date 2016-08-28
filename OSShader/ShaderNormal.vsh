
attribute vec4 position;
attribute vec2 texCoord0;
varying  vec2 texCoordVarying;
void main (){
    texCoordVarying = texCoord0;
    gl_Position = position;
}
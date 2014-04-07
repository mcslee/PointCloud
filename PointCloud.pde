import processing.opengl.*;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.nio.IntBuffer;

PVector[] points;
color[] colors;

PShader shader;
FloatBuffer vertexData;
int vertexBufferObjectName;

boolean shaderMode = true; 
float pointSize = 2;
float cameraTheta = 0;

void setup() {
  size(800, 600, OPENGL);
  colorMode(HSB, 360, 100, 100);
  
  // This is our set of points
  int size = 35;
  int spacing = 4;
  points = new PVector[size*size*size];
  colors = new int[size*size*size];
  for (int x = 0; x < size; ++x) {
    for (int y = 0; y < size; ++y) {
      for (int z = 0; z < size; ++z) {
        points[x*size*size+y*size+z] = new PVector(spacing*(x-size/2), spacing*(y-size/2), spacing*(z-size/2));
      }
    }
  }
  
  // Initialize our shader
  initializeShader();
  
  println("Usage: 's' to toggle shader mode, 'f' to show framerate, 'p' to change point size");
  println("Running in simple mode by default");
}

void initializeShader() {
  // Load shader
  shader = loadShader("frag.glsl", "vert.glsl");
  
  // Create a buffer for vertex data
  vertexData = ByteBuffer
    .allocateDirect(points.length * 7 * Float.SIZE/8)
    .order(ByteOrder.nativeOrder())
    .asFloatBuffer();
  
  // Put all the points into the buffer
  vertexData.rewind();
  for (PVector point : points) {
    // Each point has 7 floats, XYZRGBA
    vertexData.put(point.x);
    vertexData.put(point.y);
    vertexData.put(point.z);
    vertexData.put(0f);
    vertexData.put(0f);
    vertexData.put(0f);
    vertexData.put(1f);
  }
  vertexData.position(0);
  
  // Generate a buffer binding
  IntBuffer resultBuffer = ByteBuffer
    .allocateDirect(1 * Integer.SIZE/8)
    .order(ByteOrder.nativeOrder())
    .asIntBuffer();
  
  PGL pgl = beginPGL();
  pgl.genBuffers(1, resultBuffer); // Generates a buffer, places its id in resultBuffer[0]
  vertexBufferObjectName = resultBuffer.get(0); // Grab our buffer name
  endPGL();
}

void draw() {
  float radius = 250;
  background(#000000);
  camera(radius*sin(cameraTheta), 0, -radius*cos(cameraTheta), 0, 0, 0, 0, 1, 0);
  noFill();
  noStroke();
  
  int millis = millis();
  
  // Run a little animation on the colors
  for (int i = 0; i < points.length; ++i) {
    colors[i] = color(
      (millis/40. + abs(points[i].x + points[i].y + points[i].z)) % 360,
      100,
      abs(100 - ((millis/15. + abs(6*points[i].y) + abs(2*points[i].z) + abs(4*points[i].x)) % 200))
    );
  }
  
  if (shaderMode) {
    drawWithShader();
  } else {
    drawSimple();
  }
}

void drawSimple() {
  strokeWeight(pointSize);
  beginShape(POINTS);
  for (int i = 0; i < points.length; ++i) {
    stroke(colors[i]); 
    vertex(points[i].x, points[i].y, points[i].z);
  }
  endShape();
}

void drawWithShader() {
  // Put our new colors in the vertex data
  for (int i = 0; i < colors.length; ++i) {
    color c = colors[i];
    vertexData.put(7*i + 3, (0xff & (c >> 16)) / 255f); // R
    vertexData.put(7*i + 4, (0xff & (c >> 8)) / 255f); // G
    vertexData.put(7*i + 5, (0xff & (c)) / 255f); // B
  }
  
  PGL pgl = beginPGL();
  
  // Bind to our vertex buffer object, place the new color data
  pgl.bindBuffer(PGL.ARRAY_BUFFER, vertexBufferObjectName);
  pgl.bufferData(PGL.ARRAY_BUFFER, points.length * 7 * Float.SIZE/8, vertexData, PGL.DYNAMIC_DRAW);
  
  shader.bind();
  int vertexLocation = pgl.getAttribLocation(shader.glProgram, "vertex");
  int colorLocation = pgl.getAttribLocation(shader.glProgram, "color");
  pgl.enableVertexAttribArray(vertexLocation);
  pgl.enableVertexAttribArray(colorLocation);
  pgl.vertexAttribPointer(vertexLocation, 3, PGL.FLOAT, false, 7 * Float.SIZE/8, 0);
  pgl.vertexAttribPointer(colorLocation, 4, PGL.FLOAT, false, 7 * Float.SIZE/8, 3 * Float.SIZE/8);
  javax.media.opengl.GL2 gl2 = (javax.media.opengl.GL2) ((PJOGL)pgl).gl;
  gl2.glPointSize(pointSize);
  pgl.drawArrays(PGL.POINTS, 0, points.length);
  pgl.disableVertexAttribArray(vertexLocation);
  pgl.disableVertexAttribArray(colorLocation);
  shader.unbind();
  
  pgl.bindBuffer(PGL.ARRAY_BUFFER, 0);
  endPGL();
}

void keyPressed() {
  switch (key) {
  case 's':
    shaderMode = !shaderMode;
    println("Shader Mode: " + (shaderMode ? "ON" : "OFF"));
    break;
  case 'f':
    println("FPS:" + frameRate);
    break;
  case 'p':
    ++pointSize;
    if (pointSize > 5) {
      pointSize = 1;
    }
    println("Point size: " + pointSize);
    break;  
  }
}

void mouseDragged() {
  cameraTheta += .007*(mouseX - pmouseX);
}

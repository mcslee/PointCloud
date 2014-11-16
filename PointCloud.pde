import processing.opengl.*;
import javax.media.opengl.GL2;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.nio.IntBuffer;

PVector[] points;
color[] colors;

FloatBuffer vertexData;
int vertexBufferObjectName;

boolean shaderMode = true; 
float pointSize = 2;
float cameraTheta = 0;
PShader shader;

static final int FLOAT_SIZE = Float.SIZE / 8;
static final int INTEGER_SIZE = Integer.SIZE / 8;

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
  
  // Initialize shader + VBO
  shader = loadShader("frag.glsl", "vert.glsl");
  initializeVBO();
  
  println("Usage: 's' to toggle shader mode, 'f' to show framerate, 'p' to change point size");
  println("Running in shader mode by default");
}

void initializeVBO() {
  // Create a buffer for vertex data
  vertexData = ByteBuffer
    .allocateDirect(points.length * 7 * FLOAT_SIZE)
    .order(ByteOrder.nativeOrder())
    .asFloatBuffer();
  
  // Put all the points into the buffer
  vertexData.rewind();
  for (PVector point : points) {
    // Each point has 7 floats, XYZRGBA
    vertexData.put(point.x); // x
    vertexData.put(point.y); // y
    vertexData.put(point.z); // z
    vertexData.put(1f); // r
    vertexData.put(1f); // g
    vertexData.put(1f); // b
    vertexData.put(1f); // a
  }
  vertexData.position(0);
  
  // Generate a buffer binding
  IntBuffer resultBuffer = ByteBuffer
    .allocateDirect(1 * INTEGER_SIZE)
    .order(ByteOrder.nativeOrder())
    .asIntBuffer();
  
  PGL pgl = beginPGL();
  pgl.genBuffers(1, resultBuffer); // Generates a buffer, places its id in resultBuffer[0]
  vertexBufferObjectName = resultBuffer.get(0); // Grab our buffer name
  
  endPGL();
}

void draw() {
  // Set camera position
  float radius = 250;
  background(#000000);
  camera(radius*sin(cameraTheta), 0, -radius*cos(cameraTheta), 0, 0, 0, 0, 1, 0);
  
  // Reset fill and stroke
  noFill();
  noStroke();
  
  // Run a little animation on the colors
  int millis = millis();
  for (int i = 0; i < points.length; ++i) {
    colors[i] = color(
      (millis/40. + abs(points[i].x + points[i].y + points[i].z)) % 360,
      100,
      abs(100 - ((millis/15. + abs(6*points[i].y) + abs(2*points[i].z) + abs(4*points[i].x)) % 200))
    );
  }
  
  // Draw
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
  
  // Get GL2 context
  PGL pgl = beginPGL();
  GL2 gl2 = ((PJOGL)pgl).gl.getGL2();
 
  // Bind and update array buffer data 
  pgl.bindBuffer(PGL.ARRAY_BUFFER, vertexBufferObjectName);
  pgl.bufferData(PGL.ARRAY_BUFFER, points.length * 7 * FLOAT_SIZE, vertexData, PGL.DYNAMIC_DRAW);
  
  // Bind client state and data
  shader.bind();
  int vertexLocation = pgl.getAttribLocation(shader.glProgram, "vertex");
  int colorLocation = pgl.getAttribLocation(shader.glProgram, "color");
  pgl.enableVertexAttribArray(vertexLocation);
  pgl.enableVertexAttribArray(colorLocation);
  pgl.vertexAttribPointer(vertexLocation, 3, PGL.FLOAT, false, 7 * FLOAT_SIZE, 0);
  pgl.vertexAttribPointer(colorLocation, 4, PGL.FLOAT, false, 7 * FLOAT_SIZE, 3 * FLOAT_SIZE);
 
  // Set point size, disable texture map
  gl2.glEnable(GL2.GL_BLEND);
  gl2.glEnable(GL2.GL_POINT_SPRITE);
  gl2.glEnable(GL2.GL_POINT_SMOOTH);
  gl2.glDisable(GL2.GL_TEXTURE_2D);
  gl2.glPointSize(pointSize);
  
  // Draw points
  pgl.drawArrays(PGL.POINTS, 0, points.length);
 
  // Unbind
  pgl.disableVertexAttribArray(vertexLocation);
  pgl.disableVertexAttribArray(colorLocation);
  shader.unbind();
  pgl.bindBuffer(PGL.ARRAY_BUFFER, 0);
 
  // Finish PGL
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

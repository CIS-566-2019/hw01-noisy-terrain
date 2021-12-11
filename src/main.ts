import {vec3} from 'gl-matrix';
import {vec4} from 'gl-matrix';
const Stats = require('stats-js');
import * as DAT from 'dat.gui';
import Icosphere from './geometry/Icosphere';
import Square from './geometry/Square';
import Cube from './geometry/Cube';
import OpenGLRenderer from './rendering/gl/OpenGLRenderer';
import Camera from './Camera';
import {setGL} from './globals';
import ShaderProgram, {Shader} from './rendering/gl/ShaderProgram';

// Define an object with application parameters and button callbacks
// This will be referred to by dat.GUI's functions that add GUI elements.
const controls = {
  tesselations: 5,
  'Load Scene': loadScene, // A function pointer, essentially
  'ambient light': 2,
  'deform': 0,
  'lambert': lambert,
  'gradient': gradient,
  'lit': lit,
};



var palette = {
    color1: [0, 128, 255], // RGB array
};

let icosphere: Icosphere;
let square: Square;
let cube: Cube;
let prevTesselations: number = 5;
let r: number = 0;
let g: number = 0;
let b: number = 0;
let t: number = 0;
let increase: boolean = true;
let reflectionModel: number = 0;

function lambert() {
  reflectionModel = 0;
}

function gradient() {
  reflectionModel = 1;
}

function lit() {
  reflectionModel = 2;
}

function loadScene() {
  icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, controls.tesselations);
  icosphere.create();
  //square = new Square(vec3.fromValues(0, 0, 0));
  //square.create();
  //cube = new Cube(vec3.fromValues(0, 0, 0));
  //cube.create();
}

function main() {
  // Initial display for framerate
  const stats = Stats();
  stats.setMode(0);
  stats.domElement.style.position = 'absolute';
  stats.domElement.style.left = '0px';
  stats.domElement.style.top = '0px';
  document.body.appendChild(stats.domElement);

  // Add controls to the gui
  const gui = new DAT.GUI();
  gui.add(controls, 'tesselations', 0, 8).step(1);
  gui.add(controls, 'lambert');
  gui.add(controls, 'gradient');
  gui.add(controls, 'lit');
  gui.add(controls, 'Load Scene');
  gui.add(controls, 'ambient light', 0, 10).step(1);
  gui.add(controls, 'deform', 0, 10).step(1);

  // Add color controller
  //var colorController = gui.addColor(palette, 'color1');
  //colorChange();
  //colorController.onFinishChange(colorChange);

  // get canvas and webgl context
  const canvas = <HTMLCanvasElement> document.getElementById('canvas');
  const gl = <WebGL2RenderingContext> canvas.getContext('webgl2');
  if (!gl) {
    alert('WebGL 2 not supported!');
  }
  // `setGL` is a function imported above which sets the value of `gl` in the `globals.ts` module.
  // Later, we can import `gl` from `globals.ts` to access it
  setGL(gl);

  // Initial call to load scene
  loadScene();

  const camera = new Camera(vec3.fromValues(0, 0, 5), vec3.fromValues(0, 0, 0));

  const renderer = new OpenGLRenderer(canvas);
  renderer.setClearColor(0.2, 0.2, 0.2, 1);
  gl.enable(gl.DEPTH_TEST);

  const lambert = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/lambert-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/lambert-frag.glsl')),
  ]);

  const custom = new ShaderProgram([
      new Shader(gl.VERTEX_SHADER, require('./shaders/custom-vert.glsl')),
      new Shader(gl.FRAGMENT_SHADER, require('./shaders/custom-frag.glsl')),
  ]);

  const planetLambert = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/planet-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/planet-frag.glsl')),
]);

  

  /*function colorChange() {
      var newColor = colorController.getValue();
      r = newColor[0] / 255;
      g = newColor[1] / 255;
      b = newColor[2] / 255;
  }
  */

  // This function will be called every frame
  function tick() {
    camera.update();
    stats.begin();
    gl.viewport(0, 0, window.innerWidth, window.innerHeight);
    renderer.clear();
    //var color = vec4.fromValues(r, g, b, 1);
    var color = vec4.fromValues(116 / 255, 184 / 255, 121 / 255, 1);
    if(controls.tesselations != prevTesselations)
    {
      prevTesselations = controls.tesselations;
      icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, prevTesselations);
      icosphere.create();
    }
    renderer.render(camera, planetLambert, [
        icosphere,
        //cube,
        //square,
    ], color, t, controls['ambient light'], reflectionModel, controls.deform);

    //change t very tick
    t = t + 1;
    stats.end();

    // Tell the browser to call `tick` again whenever it renders a new frame
    requestAnimationFrame(tick);
    
  }

  window.addEventListener('resize', function() {
    renderer.setSize(window.innerWidth, window.innerHeight);
    camera.setAspectRatio(window.innerWidth / window.innerHeight);
    camera.updateProjectionMatrix();
  }, false);

  renderer.setSize(window.innerWidth, window.innerHeight);
  camera.setAspectRatio(window.innerWidth / window.innerHeight);
  camera.updateProjectionMatrix();

  // Start the render loop
  tick();
}

main();

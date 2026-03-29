import React, { useRef, useEffect } from 'react';
import * as THREE from 'three';

const HouseLogo3D = ({ width = 100, height = 100 }) => {
  const mountRef = useRef(null);

  useEffect(() => {
    const currentMount = mountRef.current;
    if (!currentMount) return;

    // Escena, cámara y renderizador
    const scene = new THREE.Scene();
    
    // Transparent background
    const camera = new THREE.PerspectiveCamera(75, width / height, 0.1, 1000);
    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    
    renderer.setSize(width, height);
    renderer.setPixelRatio(window.devicePixelRatio);
    currentMount.appendChild(renderer.domElement);

    // Material con los colores de Susy Market / moderno
    // Un MeshNormalMaterial es genial pero también podemos usar un Standard para reflejos
    const material = new THREE.MeshNormalMaterial();

    // Cuerpo de la casa (cubo)
    const geometryBase = new THREE.BoxGeometry(2, 2, 2);
    const base = new THREE.Mesh(geometryBase, material);
    scene.add(base);

    // Techo (pirámide)
    const geometryRoof = new THREE.ConeGeometry(2.2, 1.5, 4);
    const roof = new THREE.Mesh(geometryRoof, material);
    roof.position.y = 1.75; // encima del cubo
    roof.rotation.y = Math.PI / 4; // girar para que encaje
    scene.add(roof);

    // Posicionar cámara - alejarse lo suficiente para ver la casa
    camera.position.z = 5;
    camera.position.y = 0.5;
    
    // Inclinamos un poco la cámara para que se vea ligeramente desde arriba
    camera.lookAt(0, 0, 0);

    // Animación
    let animationId;
    const animate = () => {
      animationId = requestAnimationFrame(animate);
      
      // Rotar la casa suavemente sobre el eje Y
      base.rotation.y += 0.01;
      roof.rotation.y += 0.01;
      
      renderer.render(scene, camera);
    };
    animate();

    // Limpieza al desmontar
    return () => {
      cancelAnimationFrame(animationId);
      if (currentMount.contains(renderer.domElement)) {
        currentMount.removeChild(renderer.domElement);
      }
      geometryBase.dispose();
      geometryRoof.dispose();
      material.dispose();
      renderer.dispose();
    };
  }, [width, height]);

  return <div ref={mountRef} style={{ width, height }} />;
};

export default HouseLogo3D;

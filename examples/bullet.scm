;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; A simple little bullet Boxes demo
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(load "libs/horde3d_lib.scm")
(load "libs/bullet_lib.scm")
(load "libs/opengl_lib.scm")

(definec degToRad
  (lambda (f:float)
    (* f (/ 3.141592 180.0))))


(define _objects (sys:make-cptr (* 2000 4)))
(bind-scm _objects i32* _objects)
;; array of rigid bodies (one for each object
(define _bodies (sys:make-cptr (* 8 2000)))
(bind-scm _bodies plRigidBodyHandle* _bodies)
(define _sbodies (sys:make-cptr (* 8 5)))
(bind-scm _sbodies plRigidBodyHandle* _sbodies)

;; globals
(bind-val light i32 0)
(bind-val _x float 100.0)
(bind-val _y float 100.0)
(bind-val _cam i32 0)
(bind-val _hdrPipeRes i32 0)
(bind-val _velocity float 10.0)
(bind-val _curFPS float 30.0)
(bind-val _forwardPipeRes i32 0)
(bind-val _deferredPipeRes i32 0)
(bind-val env i32 0)

(definec resize
  (lambda (width:float height:float)
    ;; resize viewport
    (h3dSetNodeParamI _cam H3DCamera_ViewportXI 0)
    (h3dSetNodeParamI _cam H3DCamera_ViewportYI 0)
    (h3dSetNodeParamI _cam H3DCamera_ViewportWidthI (ftoi32 width))
    (h3dSetNodeParamI _cam H3DCamera_ViewportHeightI (ftoi32 height))
    ;; set virtual cam params
    (h3dSetupCameraView _cam 20.0 (/ width height) 0.1 1000.0)
    1))

(definec h3d_object_size
  (lambda (idx:i32)
    (let ((sizes (heap-alloc 6 float))
	  (results (heap-alloc 3 float)))
      (h3dGetNodeAABB (pref _objects idx)
		      (pref-ptr sizes 0) (pref-ptr sizes 1) (pref-ptr sizes 2)
		      (pref-ptr sizes 3) (pref-ptr sizes 4) (pref-ptr sizes 5))
      (pset! results 0 (- (pref sizes 3) (pref sizes 0)))
      (pset! results 1 (- (pref sizes 4) (pref sizes 1)))
      (pset! results 2 (- (pref sizes 5) (pref sizes 2)))
      results)))

(definec h3d_object_pos
  (lambda (idx:i32)
    (let ((sizes (heap-alloc 6 float))
	  (results (heap-alloc 3 float)))
      (h3dGetNodeAABB (pref _objects idx)
		      (pref-ptr sizes 0) (pref-ptr sizes 1) (pref-ptr sizes 2)
		      (pref-ptr sizes 3) (pref-ptr sizes 4) (pref-ptr sizes 5))
      (pset! results 0 (pref sizes 0))
      (pset! results 1 (pref sizes 1))
      (pset! results 2 (pref sizes 2))
      results)))
      
(definec h3d_init
  (let ((hand -1)
	(matRes -1)
	(envRes -1)
	(boxRes -1)
	(boxAnim1Res -1)
	(boxAnim2Res -1)
	(particleSysRes -1)
	(phySdk (plNewBulletSdk))
	(dynWorld (plCreateDynamicsWorld phySdk))
	(iii:i64 0)
	(z:i32 0)
	(k:i64 0)
	)
    (lambda ()
      (if (h3dInit)
	  (printf "Successfully Inited Horde3D\n")
	  (begin (h3dutDumpMessages)
		 (printf "Failed to init Horde3D\n")))
      ;; set options
      (h3dSetOption H3DOptions_LoadTextures 1)
      (h3dSetOption H3DOptions_TexCompression 0)
      (h3dSetOption H3DOptions_FastAnimation 0)
      (h3dSetOption H3DOptions_MaxAnisotropy 4)
      (h3dSetOption H3DOptions_ShadowMapSize 2048)

      ;; add resources

      ;; set resources
      (set! _hdrPipeRes (h3dAddResource H3DResTypes_Pipeline "pipelines/hdr.pipeline.xml" 0))
      (set! _forwardPipeRes (h3dAddResource H3DResTypes_Pipeline "pipelines/forward.pipeline.xml" 0))
      (set! boxRes (h3dAddResource H3DResTypes_SceneGraph "models/cube/cube.scene.xml" 0))

      ;; load resources
      (if (h3dutLoadResourcesFromDisk "Horde3D")
	  (printf "succesfully loaded resouces\n")
	  (printf "failed to load resources\n"))

      ;; log any errors to Horde3D_Log.html
      (h3dutDumpMessages)                  

      ;; add camera
      (set! _cam (h3dAddCameraNode H3DRootNode "Camera" _forwardPipeRes)) ;_hdrPipeRes))

      (let ((resy (h3dAddNodes H3DRootNode boxRes)))
	(h3dSetNodeTransform resy -500.0 0.0 0.0
			     0.0 0.0 0.0
			     1000.0 1000.0 0.1))
      ;; add boxes
      (dotimes (iii 2000)
	(let ((res (h3dAddNodes H3DRootNode boxRes)))
	  (h3dSetNodeTransform res
			       0.0 0.0 0.0
			       0.0 0.0 0.0
			       1.0 1.0 1.0)	  
	  (pset! _objects iii res)))

      ;; move objects
      (let ((v3 (heap-alloc 3 float))
	    (across 40)
	    (v4 (heap-alloc 4 float)))
	(dotimes (z (i64toi32 2000))
	  (let ((body (plCreateRigidBody null 1.0 (plNewBoxShape 1.0 1.0 1.0))))
	    (plSetActivationState body 4)	    
	    (pset! _bodies z body)
	    (pfill! v3 (* 5.0 (i32tof (modulo z across))) (* 5.0 (i32tof (/ (modulo z 2000) across))) 0.0) ;(dtof (- (* 2.0 (random)) 1.0)))
	    (plSetPosition body v3)
	    (plSetEuler 0.0 0.0 0.0 v4)
	    (plSetOrientation body v4)
	    (plAddRigidBody dynWorld body))))

      (let ((v33 (heap-alloc 3 float))
	    (v44 (heap-alloc 4 float)))
	(dotimes (k 5)
	  (let ((stiffbody (plCreateRigidBody null 0.0 (plNewBoxShape 10.0 10.0 1000.0))))
	    (pset! _sbodies k stiffbody)
	    (pfill! v33 (+ 30.0 (* (i64tof k) 40.0)) 20.0 200.0)
	    (pfill! v44 0.0 0.0 0.0 1.0)
	    (plSetPosition stiffbody v33)
	    (plSetOrientation stiffbody v44)
	    (plAddRigidBody dynWorld stiffbody))))
      
      
      ;; add light source
      (set! light (h3dAddLightNode H3DRootNode "Light1" 0 "LIGHTING" "SHADOWMAP"))
      (h3dSetNodeTransform light 0.0 0.0 10.0
			         0.0 0.0 0.0
				 1.0 1.0 1.0)
      (h3dSetNodeParamF light H3DLight_RadiusF 0 1000.0)
      (h3dSetNodeParamF light H3DLight_FovF 0 90.0)
      (h3dSetNodeParamI light H3DLight_ShadowMapCountI 1)
      (h3dSetNodeParamF light H3DLight_ShadowMapBiasF 0 0.01)
      (h3dSetNodeParamF light H3DLight_ColorF3 0 1.0)
      (h3dSetNodeParamF light H3DLight_ColorF3 1 0.8)
      (h3dSetNodeParamF light H3DLight_ColorF3 2 0.7)
      (h3dSetNodeParamF light H3DLight_ColorMultiplierF 0 1.0)
      
      (resize 900.0 600.0)
      
      1)))


(definec mainLoop
  (let ((_at:double 0.0)
	(matrix (heap-alloc 16 float))
	(pos (heap-alloc 3 float))
	(fps:float 30.0)
	(z:i32 0)
	(k 0))
    (lambda ()     
      (set! _curFPS fps)
      (h3dSetOption H3DOptions_DebugViewMode 0.0)
      (h3dSetOption H3DOptions_WireframeMode 0.0)
           
      ;; step simulation
      (set! _at (+ _at 0.03))
      (pfill! pos 0.0 -2000.0 0.0)
      (plSetGravity (h3d_init.dynWorld:plDynamicsWorldHandle) pos)
      (plStepSimulation (h3d_init.dynWorld:plDynamicsWorldHandle) 1.0 1 (/ 1.0 260.0)) ;(dtof _at))

;      (pfill! pos (+ 60.0 (* 50.0 (dtof (cos (* _at .25))))) 20.0 200.0)
 ;     (plSetPosition (pref _sbodies 0) pos))
      (pfill! pos _x _y 200.0)
      (plSetPosition (pref _sbodies 4) pos)

      (dotimes (z (i64toi32 2000))
      	(plGetPosition (pref _bodies z) pos)
      	(plGetOpenGLMatrix (pref _bodies z) matrix)
      	(h3dSetNodeTransMat (pref _objects z) matrix)	
      	(if (< (pref pos 1) -30.0)
      	    (let ((body (pref _bodies z)))	      
      	      (pfill! pos (* 4.0 (i32tof (modulo z 40))) 90.0 0.0) ;(* 3.0 (dtof (random))))
      	      (plSetPosition body pos)
      	      (pfill! pos 0.0 -100.0 0.0)
      	      (plSetLinearVelocity body pos)
      	      (pfill! pos 0.0 0.0 0.0)
      	      (plSetAngularVelocity body pos)
      	      (plClearForces body))))

      ;; some lighting guff
      (h3dSetNodeParamF light H3DLight_RadiusF 0 300.0)
      (h3dSetNodeParamF light H3DLight_FovF 0 120.0)
      (h3dSetNodeParamI light H3DLight_ShadowMapCountI 1)
      (h3dSetNodeParamF light H3DLight_ShadowMapBiasF 0 0.01)
      (h3dSetNodeParamF light H3DLight_ColorF3 0 1.0) ;(dtof (cos _at)))
      (h3dSetNodeParamF light H3DLight_ColorF3 1 1.0)
      (h3dSetNodeParamF light H3DLight_ColorF3 2 1.0)
      (h3dSetNodeParamF light H3DLight_ColorMultiplierF 0 1.0)

      (h3dSetNodeTransform light
      			   85.0 150.0 50.0
      			   -90.0 -45.0 0.0
      			   1.0 1.0 1.0)

      (h3dSetNodeTransform _cam 90.0 30.0 400.0 0.0 0.0 0.0 1.0 1.0 1.0)      
      (h3dRender _cam)
      (h3dFinalizeFrame)
      (h3dutDumpMessages)
      1)))

(definec rot
  (lambda (deg x y z)
    (glRotated deg x y z)))

(definec set-mouse-pos
  (lambda (x y)
    (set! _x (/ (i64tof x) 5.0))
    (set! _y (/ (- 360.0 (i64tof y)) 4.5))
    void))

;; standard impromptu callback
(define opengl-test
  (lambda (time degree)
    (let ((c (clock:clock)))
      (let ((evt (gl:get-event)))
	(if (not (null? evt))
	    (set-mouse-pos (cadr evt) (car evt))))
      (mainLoop)
      (gl:swap-buffers pr2)
      (callback (+ time 50) 'opengl-test (+ time 512) (+ degree 0.001)))))


(define pr2 (gl:make-ctx ":0.0" #f 0.0 0.0 900.0 600.0))
(h3d_init)
(opengl-test (now) 0.0)
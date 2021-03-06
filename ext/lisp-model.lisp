(in-package #:gtk-cffi-ext)

(defclass lisp-model-impl ()
  ((columns :initarg :columns :accessor columns)))

(defclass lisp-model-list (lisp-model-impl)
  ())

(defclass lisp-model-tree (lisp-model-impl)
  ())

;; 1    1
;; 2      1.1
;; 3      1.2
;; 4    2
;; 5      2.1
;; 6        2.1.1
;; tree = (child*)
;; child = (row child*)
;; row = (field*)
;; path = (index*)
;; (((1) ((1.1)) ((1.2))) ((2) ((2.1) ((2.1.1)))))
;;
;; a[i] = (cons path child)

(defstruct node
  (parent nil :type (or null node))
  (children nil :type (or null (vector node)))
  (address "" :type string)
  (index 0 :type fixnum))
  

(defun make-tree-array (tree)
  (let (res arr-tree)
    (labels ((process-child (child)
               (declare (special i prefix))
               (let ((address (concatenate 'string prefix ":" 
                                           (princ-to-string i))))
                 (let ((index (length res))) 
                   (push (cons (subseq address 1) (car child)) res)
                   (incf i)
                   (let ((i 0) (prefix address))
                         (declare (special i prefix))
                         (cons index
                               (process (cdr child)))))))
             (process (seq)
               (let ((l (mapcar #'process-child seq)))
                 (when l (coerce l 'simple-vector)))))
      (let ((i 0) prefix)
        (declare (special i prefix))
        (setf arr-tree (process tree))))
    (values (coerce (nreverse res) 'simple-vector) arr-tree)))

(defclass lisp-model-tree-array (lisp-model-tree)
  ((array :accessor larray :type (array tree-item))
   (tree :accessor tree :type list))
  (:documentation 
   "ARRAY should contain lists with address as car and columns data as cdr"))

(defmethod shared-initialize :after ((o lisp-model-tree-array) slot-names 
                                     &key tree)
  (setf (values (larray o) (tree o)) (make-tree-array tree)))

(defclass lisp-model-array (lisp-model-list)
  ((array :initarg :array :accessor larray :type (array list)))
  (:documentation "ARRAY should contain lists with columns data"))

(defgeneric get-flags (lisp-model-impl)
  (:method ((lisp-model-list lisp-model-list))
    2)
  (:method ((lisp-model-tree lisp-model-tree))
    0))

(defgeneric get-n-columns (lisp-model-impl)
  (:method ((lisp-model-impl lisp-model-impl))
    (length (columns lisp-model-impl))))

(defgeneric get-column-type (lisp-model-impl index)
  (:method ((lisp-model-impl lisp-model-impl) index)
    (keyword->g-type (nth index (columns lisp-model-impl)))))

(defgeneric lisp-model-length (lisp-model-list)
  (:method ((lisp-model-array lisp-model-array))
    (length (larray lisp-model-array))))

(defgeneric get-iter (lisp-model iter path)
  (:method ((lisp-model-impl lisp-model-impl) iter path)
    (warn "Undefined implementation of GET-ITER for ~a" lisp-model-impl)))

(defun set-iter (iter index)
  (setf (stamp iter) 0
        (u1 iter) (make-pointer index))
  t)

(defmethod get-iter ((lisp-model-list lisp-model-list) iter path)
  (let ((index (aref path 0)))
    (when (< index (lisp-model-length lisp-model-list))
      (set-iter iter index))))

(defun descend (tree address)
  (when (> (length tree) (car address))
    (let ((child (aref tree (car address))))
      (if (cdr address)
          (descend (cdr child) (cdr address))
          (values t (car child) (cdr child))))))

(defmethod get-iter ((lisp-model lisp-model-tree-array) iter path)
  (multiple-value-bind (found index) (descend (tree lisp-model) 
                                              (coerce path 'list))
    (when found (set-iter iter index))))

(defun iter->index (iter)
  (pointer-address (u1 iter)))

(defun iter->aref (lisp-model iter)
  (aref (larray lisp-model) (iter->index iter)))
  
(defgeneric get-path (lisp-model-impl iter)
  (:method ((lisp-model-list lisp-model-list) iter)
    (list (iter->index iter)))
  (:method ((lisp-model lisp-model-tree-array) iter)
    (car (iter->aref lisp-model iter))))

(defun set-value (g-value value-list n)
  (g-object-cffi::init-g-value g-value nil (nth n value-list) t))


(defgeneric get-value (lisp-model-impl iter n value)
  (:method ((lisp-model lisp-model-array) iter n value)
    (set-value value (iter->aref lisp-model iter) n))
  (:method ((lisp-model lisp-model-tree-array) iter n value)
    (set-value value (cdr (iter->aref lisp-model iter)) n)))

(defun set-iter-checked (lisp-model-list iter index)
  (when (and (>= index 0) (< index (lisp-model-length lisp-model-list)))
    (set-iter iter index)))

(defun path-string->list (str)
  (let (res (buf ""))
    (iter
     (for ch in-string str)
     (if (char-equal ch #\:)
         (progn
          (push (parse-integer buf) res)
          (setf buf ""))
         (setf buf (concatenate 'string buf 
                                (make-string 1 :initial-element ch))))) 
    (push (parse-integer buf) res) 
    (nreverse res)))                

(defun iter->path-list (tree iter)
  (path-string->list (car (iter->aref tree iter))))
  

(defun move-tree-iter-checked (lisp-model-tree iter delta)
  (multiple-value-bind (found index)
      (descend (tree lisp-model-tree)
               (let ((r (iter->path-list lisp-model-tree iter)))
                 (incf (car (last r)) delta)
                 r))
    (when found (set-iter iter index))))

(defgeneric iter-next (lisp-model-impl iter)
  (:method ((lisp-model-list lisp-model-list) iter)
    (set-iter-checked lisp-model-list iter (1+ (iter->index iter))))
  (:method ((lisp-model lisp-model-tree-array) iter)
    (move-tree-iter-checked lisp-model iter 1)))

(defgeneric iter-previous (lisp-model-impl iter)
  (:method ((lisp-model-list lisp-model-list) iter)
    (set-iter-checked lisp-model-list iter (1- (iter->index iter))))
  (:method ((lisp-model lisp-model-tree-array) iter)
    (move-tree-iter-checked lisp-model iter -1)))

(defgeneric iter-children (lisp-model-impl iter parent)
  (:method ((lisp-model-list lisp-model-list) iter parent)
;    (break)
    (unless parent
      (set-iter iter 0)))
  (:method ((lisp-model lisp-model-tree-array) iter parent)
    (multiple-value-bind (found index)
        (descend (tree lisp-model)
                 (let ((r (iter->path-list lisp-model parent)))
                   (append r '(0))))
      (when found (set-iter iter index)))))

(defgeneric iter-has-child (lisp-model-impl iter)
  (:method ((lisp-model-list lisp-model-list) iter)
    nil)
  (:method ((lisp-model lisp-model-tree-array) iter)
    (descend (tree lisp-model)
             (let ((r (iter->path-list lisp-model iter)))
               (append r '(0))))))

(defgeneric iter-n-children (lisp-model-impl iter)
  (:method ((lisp-model-list lisp-model-list) iter)
    0)
  (:method ((lisp-model lisp-model-tree-array) iter)
    (multiple-value-bind (found index children)
        (descend (tree lisp-model)
                 (iter->path-list lisp-model iter))
      (declare (ignore found index))
      (length children))))

(defgeneric iter-nth-child (lisp-model-impl iter parent n)
  (:method ((lisp-model-list lisp-model-list) iter parent n) 
    (when (and (null parent) (< n (lisp-model-length lisp-model-list)))
        (set-iter iter n)))
  (:method ((lisp-model lisp-model-tree-array) iter parent n)
    (multiple-value-bind (found index)
        (descend (tree lisp-model)
                 (if (null parent)
                     (list n)
                     (let ((r (iter->path-list lisp-model parent)))
                       (append r (list n)))))
      (when found (set-iter iter index)))))

(defgeneric iter-parent (lisp-model-impl iter child)
  (:method ((lisp-model-list lisp-model-list) iter child)
    nil)
  (:method ((lisp-model lisp-model-tree-array) iter child)
    (multiple-value-bind (found index)
        (descend (tree lisp-model)
                 (let ((r (iter->path-list lisp-model child)))
                   (butlast r)))
      (when found (set-iter iter index)))))

(defgeneric ref-node (lisp-model-impl iter)
  (:method ((lisp-model-impl lisp-model-impl) iter)
    nil))

(defgeneric unref-node (lisp-model-impl iter)
  (:method ((lisp-model-impl lisp-model-impl) iter)
    nil))

(defclass lisp-model (g-object tree-model)
  ((implementation :type standard-object
                   :initarg :implementation
                   :initform (error "Implementation not set")
                   :reader implementation)))

(defcallback cb-lisp-model-class-init :void ((class :pointer))
  (declare (ignore class))
  (debug-out "Class init called~%"))

(defcallback cb-lisp-model-init :void ((self :pointer))
  (declare (ignore self))
  (debug-out "Object init called~%"))

(defmacro init-interface (interface &rest callbacks)
  `(progn
     ,@(loop :for (callback args) :on callbacks :by #'cddr
        :collecting
         `(defcallback ,(symbolicate '#:cb- callback) ,(car args) 
              ((object pobject) ,@(cdr args))
            ;(debug-out "callback: ~a~%" ',callback)
            (,callback (implementation object) ,@(mapcar #'car (cdr args)))))
     (defcallback ,(symbolicate  '#:cb-init- interface) 
         :void ((class ,interface))
       ,@(loop :for (callback args) :on callbacks :by #'cddr
            :collecting `(setf (foreign-slot-value class 
                                                   ',interface ; :struct
                                                   ',callback)
                               (callback ,(symbolicate '#:cb- callback)))))))

(init-interface 
 tree-model-iface
 get-flags (:int)
 get-n-columns (:int)
 get-column-type (:int (index :int))
 get-iter (:boolean (iter (object tree-iter))
                    (path ptree-path))
 get-path (ptree-path (iter (object tree-iter)))
 get-value (:void (iter (object tree-iter)) (n :int)
                  (value :pointer))
 iter-next (:boolean (iter (object tree-iter)))
 iter-previous (:boolean (iter (object tree-iter)))
 iter-children (:boolean (iter (object tree-iter)) 
                         (parent (object tree-iter))) 
 iter-has-child (:boolean (iter (object tree-iter)))
 iter-n-children (:int (iter (object tree-iter)))
 iter-nth-child (:boolean (iter (object tree-iter)) 
                          (parent (object tree-iter)) (n :int))
 iter-parent (:boolean (iter (object tree-iter)) 
                       (child (object tree-iter)))
 ref-node (:void (iter (object tree-iter)))
 unref-node (:void (iter (object tree-iter))))


(defcstruct g-interface-info
  (init :pointer)
  (finalize :pointer)
  (data pdata))

(defcfun gtk-tree-model-get-type :uint) 

(defgeneric get-type (lisp-model))
(let ((interface-info (foreign-alloc 'g-interface-info))
      g-type)
  (setf (foreign-slot-value interface-info 'g-interface-info 'init)
        (callback cb-init-tree-model-iface))
  (defmethod get-type ((lisp-model lisp-model))
    (or g-type
        (prog1
            (setf g-type
                  (g-type-register-static-simple
                   #.(keyword->g-type :object)
                   (g-intern-static-string "GtkLispModel")
                   (foreign-type-size 'g-object-class-struct)
                   (callback cb-lisp-model-class-init)
                   (foreign-type-size 'g-object)
                   (callback cb-lisp-model-init)
                   0))
          
          (g-type-add-interface-static g-type
                                       (gtk-tree-model-get-type)
                                       interface-info)))))

(defmethod gconstructor ((lisp-model lisp-model) &rest initargs)
  (declare (ignore initargs))
  (new (get-type lisp-model)))

(import 'lisp-model "GTK-CFFI")
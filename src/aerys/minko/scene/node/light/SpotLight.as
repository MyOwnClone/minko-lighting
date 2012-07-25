package aerys.minko.scene.node.light
{
	import aerys.minko.ns.minko_math;
	import aerys.minko.render.resource.texture.TextureResource;
	import aerys.minko.scene.node.ISceneNode;
	import aerys.minko.scene.node.Scene;
	import aerys.minko.type.binding.DataBindings;
	import aerys.minko.type.enum.ShadowMappingType;
	import aerys.minko.type.math.Matrix4x4;
	import aerys.minko.type.math.Vector4;
	
	public class SpotLight extends AbstractLight
	{
		use namespace minko_math;
		
		public static const TYPE			: uint				= 3;
		
		private static const TMP_VECTOR		: Vector4			= new Vector4();
		private static const Z_AXIS			: Vector4			= new Vector4(0, 0, 1);
		private static const SCREEN_TO_UV	: Matrix4x4			= new Matrix4x4(
			0.5,		0.0,		0.0,	0.0,
			0.0, 		-0.5,		0.0,	0.0,
			0.0,		0.0,		1.0,	0.0,
			0.5, 		0.5,		0.0, 	1.0
		);
		
		private static const FRUSTUM_POINTS	: Vector.<Vector4>	= new <Vector4>[
			new Vector4(-1, -1, 0, 1),
			new Vector4(-1, -1, 1, 1),
			new Vector4(-1, +1, 0, 1),
			new Vector4(-1, +1, 1, 1),
			new Vector4(+1, -1, 0, 1),
			new Vector4(+1, -1, 1, 1),
			new Vector4(+1, +1, 0, 1),
			new Vector4(+1, +1, 1, 1)
		];
		
		private var _worldPosition	: Vector4;
		private var _worldDirection	: Vector4;
		private var _projection		: Matrix4x4;
		private var _worldToScreen	: Matrix4x4;
		private var _worldToUV		: Matrix4x4;
		
		public function get diffuse() : Number
		{
			return getProperty('diffuse') as Number;
		}
		
		public function get specular() : Number
		{
			return getProperty('specular') as Number;
		}
		
		public function get shininess() : Number
		{
			return getProperty('shininess') as Number;
		}
		
		public function get innerRadius() : Number
		{
			return getProperty('innerRadius') as Number;
		}
		
		public function get outerRadius() : Number
		{
			return getProperty('outerRadius') as Number;
		}
		
		public function get attenuationDistance() : Number
		{
			return getProperty('attenuationDistance') as Number;
		}
		
		public function set diffuse(v : Number)	: void
		{
			setProperty('diffuse', v);
			
			if (getProperty('diffuseEnabled') != (v != 0))
				setProperty('diffuseEnabled', v != 0);
		}
		
		public function set specular(v : Number) : void
		{
			setProperty('specular', v);
			
			if (getProperty('specularEnabled') != (v != 0))
				setProperty('specularEnabled', v != 0);
		}
		
		public function set shininess(v : Number) : void
		{
			setProperty('shininess', v);
		}
		
		public function set innerRadius(v : Number) : void
		{
			setProperty('innerRadius', v);
			
			if (getProperty('smoothRadius') != (innerRadius != outerRadius))
				setProperty('smoothRadius', innerRadius != outerRadius)
		}
		
		public function set outerRadius(v : Number) : void
		{
			setProperty('outerRadius', v);
			updateProjectionMatrix();
			
			if (getProperty('smoothRadius') != (innerRadius != outerRadius))
				setProperty('smoothRadius', innerRadius != outerRadius)
		}
		
		public function set attenuationDistance(v : Number) : void
		{
			setProperty('attenuationDistance', v);
			updateProjectionMatrix();
			
			if (getProperty('attenuationEnabled') != (v != 0))
				setProperty('attenuationEnabled', v != 0);
		}
		
		override public function set shadowCastingType(v : uint) : void
		{
			var shadowMapSize	: uint = this.shadowMapSize;
			var shadowMap		: TextureResource = getProperty('shadowMap') as TextureResource;
			
			if (shadowMap)
			{
				removeProperty('shadowMap');
				shadowMap.dispose(); 
			}
			
			switch (v)
			{
				case ShadowMappingType.NONE:
					setProperty('shadowCastingType', ShadowMappingType.NONE);
					break;
				
				case ShadowMappingType.MATRIX:
					if (!((shadowMapSize & (~shadowMapSize + 1)) == shadowMapSize
						&& shadowMapSize <= 2048))
						throw new Error(shadowMapSize + ' is an invalid size for a shadow map');
					
					shadowMap = new TextureResource(shadowMapSize, shadowMapSize);
					setProperty('shadowMap', shadowMap);
					setProperty('shadowCastingType', ShadowMappingType.MATRIX);
					break;
				
				default: 
					throw new ArgumentError('Invalid shadow casting type.');
			}
		}
		
		
		public function SpotLight(color					: uint		= 0xFFFFFFFF,
								  diffuse				: Number	= .6,
								  specular				: Number	= .8,
								  shininess				: Number	= 64,
								  attenuationDistance	: Number	= 0,
								  outerRadius			: Number	= 1.57079632679,
								  innerRadius			: Number	= 0,
								  emissionMask			: uint		= 0x1,
								  shadowCastingType		: uint		= 0,
								  shadowMapSize			: uint		= 512)
		{
			_worldDirection = new Vector4();
			_worldPosition	= new Vector4();
			_projection		= new Matrix4x4();
			_worldToScreen	= new Matrix4x4();
			_worldToUV		= new Matrix4x4();
			
			super(color, emissionMask, shadowCastingType, shadowMapSize, TYPE)
			
			this.diffuse				= diffuse;
			this.specular				= specular;
			this.shininess				= shininess;
			this.innerRadius			= innerRadius;
			this.outerRadius			= outerRadius;
			this.attenuationDistance	= attenuationDistance;
			
			setProperty('worldDirection', _worldDirection);
			setProperty('worldPosition', _worldPosition);
			setProperty('projection', _projection);
			setProperty('worldToScreen', _worldToScreen);
			setProperty('worldToUV', _worldToUV);
			
			if ([ShadowMappingType.NONE, 
				ShadowMappingType.MATRIX].indexOf(shadowCastingType) == -1)
				throw new Error('Invalid ShadowMappingType.');
		}
		
		override protected function addedToSceneHandler(child : ISceneNode, scene : Scene) : void
		{
			super.addedToSceneHandler(child, scene);
			
			scene.bindings.addCallback('screenToWorld', cameraScreenToWorldChangedHandler);
			updateProjectionMatrix();
		}
		
		override protected function removedFromSceneHandler(child : ISceneNode, scene : Scene) : void
		{
			super.removedFromSceneHandler(child, scene);
			
			scene.bindings.removeCallback('screenToWorld', cameraScreenToWorldChangedHandler);
		}
		
		override protected function transformChangedHandler(transform : Matrix4x4, propertyName : String) : void
		{
			super.transformChangedHandler(transform, propertyName);
			
			_worldPosition	= localToWorld.getTranslation(_worldPosition);
			_worldDirection	= localToWorld.deltaTransformVector(Vector4.Z_AXIS, _worldDirection);
			_worldDirection.normalize();
			
			_worldToScreen.lock().copyFrom(worldToLocal).append(_projection).unlock();
			_worldToUV.lock().copyFrom(_worldToScreen).append(SCREEN_TO_UV).unlock();
		}
		
		protected function cameraScreenToWorldChangedHandler(sceneBindings	: DataBindings,
															 propertyName	: String,
															 oldValue		: Matrix4x4,
															 newValue		: Matrix4x4) : void
		{
			updateProjectionMatrix();
		}
		
		private function updateProjectionMatrix() : void
		{
			if (!(root is Scene))
				return;
			
			var screenToWorld : Matrix4x4 = 
				Scene(root).bindings.getProperty('screenToWorld') as Matrix4x4;
			
			if (screenToWorld == null)
			{
				// No camera on scene, we cannot compute a valid projection matrix.
				// For now we default to identity
				_projection.identity();
			}
			else
			{
				// There is a camera in the scene
				// We convert the frustum into light space, and compute a projection
				// matrix that contains the whole frustum.
				var zNear	: Number = Number.POSITIVE_INFINITY;
				var zFar	: Number = Number.NEGATIVE_INFINITY;
				
				for (var pointId : uint = 0; pointId < 8; ++pointId)
				{
					screenToWorld.transformVector(FRUSTUM_POINTS[pointId], TMP_VECTOR);
					TMP_VECTOR.scaleBy(1 / TMP_VECTOR.w);
					worldToLocal.transformVector(TMP_VECTOR, TMP_VECTOR);
					
					// that's unoptimized, we should compute frustum intersection here
					TMP_VECTOR.z > zFar  && (zFar  = TMP_VECTOR.z);
					TMP_VECTOR.z < zNear && (zNear = TMP_VECTOR.z);
				}
				
				// if attenuation is enabled, at d = distance * 10, 
				// we can only see 1% of the light emitted, so we can lower the zFar
				var attenuationEnabled	: Boolean	= getProperty('attenuationEnabled');
				var attenuationDistance	: Number	= this.attenuationDistance;
				
				if (zNear < 0.1)
					zNear = 0.1;
				
				if (attenuationEnabled && zFar > 10 * attenuationDistance)
					zFar = 10 * attenuationDistance;
				
				var fd	: Number = 1. / Math.tan(outerRadius * 0.5);
				var m33	: Number = 1. / (zFar - zNear);
				var m43	: Number = -zNear / (zFar - zNear);
				_projection.initialize(fd, 0, 0, 0, 0, fd, 0, 0, 0, 0, m33, 1, 0, 0, m43, 0);
			}
			
			_worldToScreen.lock().copyFrom(worldToLocal).append(_projection).unlock();
			_worldToUV.lock().copyFrom(_worldToScreen).append(SCREEN_TO_UV).unlock();
		}
		
		override public function clone(cloneControllers:Boolean=false):ISceneNode
		{
			var light : SpotLight = new SpotLight(
				color, diffuse, specular, shininess, 
				attenuationDistance, 
				outerRadius, innerRadius, emissionMask, 
				shadowCastingType, shadowMapSize
			); 
			
			light.name = this.name;
			light.transform.copyFrom(this.transform);
			
			return light;
		}
	}
}

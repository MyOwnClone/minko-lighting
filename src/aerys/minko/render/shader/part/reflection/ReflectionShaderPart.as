package aerys.minko.render.shader.part.reflection
{
	import aerys.minko.render.effect.reflection.ReflectionProperties;
	import aerys.minko.render.shader.SFloat;
	import aerys.minko.render.shader.Shader;
	import aerys.minko.render.shader.part.lighting.LightAwareShaderPart;
	import aerys.minko.render.shader.part.projection.BlinnNewellProjectionShaderPart;
	import aerys.minko.render.shader.part.projection.ProbeProjectionShaderPart;
	import aerys.minko.type.enum.ReflectionType;
	import aerys.minko.type.enum.SamplerDimension;
	import aerys.minko.type.enum.SamplerFiltering;
	import aerys.minko.type.enum.SamplerMipMapping;
	import aerys.minko.type.enum.SamplerWrapping;
	
	import flash.geom.Rectangle;
	
	public class ReflectionShaderPart extends LightAwareShaderPart
	{
		private var _blinnNewellProjectionPart	: BlinnNewellProjectionShaderPart;
		private var _probeProjectionPart		: ProbeProjectionShaderPart;
		
		public function ReflectionShaderPart(main : Shader)
		{
			super(main);
			
			_blinnNewellProjectionPart	= new BlinnNewellProjectionShaderPart(main);
			_probeProjectionPart		= new ProbeProjectionShaderPart(main);
		}
		
		public function getReflectionColor() : SFloat
		{
			// compute reflected vector
			var cWorldCameraPosition	: SFloat = this.cameraPosition;
			var vsWorldVertexToCamera	: SFloat = normalize(subtract(cWorldCameraPosition, vsWorldPosition));
			var reflected				: SFloat = normalize(interpolate(reflect(vsWorldVertexToCamera.xyzz, vsWorldNormal.xyzz)));
			var reflectionType 			: int	 = meshBindings.getConstant(ReflectionProperties.TYPE);
			
			// retrieve reflection color from reflection map
			var reflectionMap			: SFloat;
			var reflectionMapUV			: SFloat;
			var reflectionColor			: SFloat;
			
			switch (reflectionType)
			{
				case ReflectionType.NONE:
					reflectionColor = float4(0, 0, 0, 0);
					break;
				
				case ReflectionType.PROBE:
					reflectionMap	= meshBindings.getTextureParameter(ReflectionProperties.MAP);
					reflectionMapUV = _probeProjectionPart.projectVector(reflected, new Rectangle(0, 0, 1, 1));
					reflectionColor = sampleTexture(reflectionMap, reflectionMapUV);
					break;
				
				case ReflectionType.BLINN_NEWELL:
					reflectionMap	= meshBindings.getTextureParameter(ReflectionProperties.MAP);
					reflectionMapUV = _blinnNewellProjectionPart.projectVector(reflected, new Rectangle(0, 0, 1, 1));
					reflectionColor = sampleTexture(reflectionMap, reflectionMapUV);
					break;
				
				case ReflectionType.CUBE:
					reflectionMap	= meshBindings.getTextureParameter(
						ReflectionProperties.MAP, 
						SamplerFiltering.NEAREST, SamplerMipMapping.DISABLE, SamplerWrapping.CLAMP, SamplerDimension.CUBE
					);
					reflectionColor = sampleTexture(reflectionMap, reflected);
					break
				
				default:
					throw new Error('Unsupported reflection type');
			}
			
			// modifify alpha color
			if (meshBindings.propertyExists(ReflectionProperties.ALPHA_MULTIPLIER))
			{
				var alphaModifier : SFloat = meshBindings.getParameter(ReflectionProperties.ALPHA_MULTIPLIER, 1);
				
				reflectionColor = float4(reflectionColor.xyz, multiply(reflectionColor.w, alphaModifier));
			}
			
			return reflectionColor;
		}
	}
}

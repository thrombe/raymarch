
[[group(0), binding(3)]]
var compute_texture: texture_storage_2d<rgba32float, read_write>;

/// import ./src/main.wgsl
/// import ./src/vertex.wgsl
/// import ./src/rng.wgsl

/// import ./src/sdfs.wgsl

let AA = 1;

fn map(pos: v3f) -> f32 {
    var p = pos.xzy;
    var res = 0.0
    // + chocolate_fountain_blob_thing(p)
    + sdf_new(p)
    ;
    return res;
}

// http://iquilezles.org/www/articles/normalsSDF/normalsSDF.htm
fn calcNormal(pos: v3f) -> v3f {
    let e = v2f(1.0,-1.0)*0.5773; // 1/root3 = 0.5773
    let eps = 0.0005;
    return normalize(
        e.xyy*map(pos + e.xyy*eps) + 
		e.yyx*map(pos + e.yyx*eps) + 
		e.yxy*map(pos + e.yxy*eps) + 
		e.xxx*map(pos + e.xxx*eps)
    );
}
    
[[stage(fragment)]]
fn main_fragment([[builtin(position)]] pos: vec4<f32>) -> [[location(0)]] vec4<f32> {
    let input_coords = pos;
    // camera movement	
	let an = 0.7*stuff.time*0.0 + PI/2.0;
	let ro = v3f(1.0*cos(an), 10.2, 2.0*sin(an));
    let ta = v3f(0.0, 0.0, 0.0);
    // camera matrix
    let ww = normalize(ta - ro);
    let uu = normalize(cross(ww,v3f(0.0,1.0,0.0)));
    let vv =          (cross(uu,ww));
    
    // render
    var tot = v3f(0.0);
    
    for(var m=0; m<AA; m = m+1) {
        for(var n=0; n<AA; n = n+1) {
            // pixel coordinates
            let o = v2f(f32(m),f32(n)) / f32(AA) - 0.5;
            let p = (-v2f(f32(stuff.display_width), f32(stuff.display_height)) + 2.0*(pos.xy+o))/f32(stuff.display_height);

            // create view ray
            let rd = normalize(p.x*uu + p.y*vv + 1.5*ww);

            // raymarch
            let tmax = 100.0;
            var t = 0.0;
            for(var i=0; i<256; i = i+1) {
                let pos = ro + t*rd;
                let h = map(pos);
                // simplest condition is -> (t<0.0001)
                // adding doing abs(h) makes the raymarcher go backwards and forwards when the ray goes inside objects (as t+h) and will converge more at the surface
                // doing h < 0.0001*t makes the h distance dependent, so things further away have less defined constraints on how close the ray should get
                // doing max(t, 7) makes the h non distance dependent till t reaches 7 (is this needed tho?)
                // if(abs(h)<0.0001*max(t, 7.0) || t>tmax) {break;}
                // if(h<0.0001*max(t, 7.0) || t>tmax) {break;}
                if(abs(h)<0.0001*t || t>tmax) {break;}
                t = t+h;
            }
            
        
            // shading/lighting	
            var col = v3f(0.0);
            if(t<tmax) {
                let pos = ro + t*rd;
                let nor = calcNormal(pos);
                let dif = clamp(dot(nor,v3f(0.57703)), 0.0, 1.0);
                let amb = 0.5 + 0.5*dot(nor,v3f(0.0,1.0,0.0));
                col = v3f(0.2,0.3,0.4)*amb + v3f(0.8,0.7,0.5)*dif;
            }

            // gamma
            col = sqrt(col); // does monitor/gpu do this or no?
            tot = tot + col;
        }
    }
    tot = tot/f32(AA*AA);

    let tot = v4f(tot, 1.0);
    let pos = input_coords;
    textureStore(compute_texture, vec2<i32>(i32(pos.x), i32(pos.y)), tot);
	return tot;
}


[[stage(fragment)]]
fn za_main_fragment([[builtin(position)]] pos: vec4<f32>) -> [[location(0)]] vec4<f32> {
    var col = textureLoad(compute_texture, vec2<i32>(i32(pos.x), i32(pos.y))).xyz;
    return v4f(col, 1.0);
}


[[group(0), binding(3)]]
var compute_texture: texture_storage_2d<rgba32float, read_write>;

/// import ./src/main.wgsl
/// import ./src/vertex.wgsl
/// import ./src/rng.wgsl

let AA = 1;

fn sphere(pos: v3f, r: f32) -> f32 {
    return length(pos)-r;
}


fn usd_box(p: v3f, b: v3f) -> f32{
    return length(max(abs(p)-b, v3f(0.0) ) );
}

fn sd_box(p: v3f, b: v3f) -> f32 {
  let d = abs(p) - b;
  return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d, v3f(0.0)));
}

fn smoothmin(d_a: f32, d_b: f32, k: f32) -> f32 {
    let h = max(k-abs(d_a-d_b), 0.0)/k;
    return min(d_a, d_b) - h*h*h*k/6.0;
}



fn map(pos: v3f) -> f32 {
    var p = pos;
    p = p.xzy;
    p = p + v3f(0.0, -2.0, 3.0);
    let op = p;
    var res = v3f(-1.0,-1.0,0.5);

    p.y = p.y + 2.0;

    // bounding box
    let bbox = usd_box(p,v3f(15.0,12.0,15.0)*1.5 );
    if( bbox>5.0 ) {
        return v3f(bbox+1.0,-1.0,0.5).x;
    }


    let t = stuff.time;

    var q = p;
    //q += vec3(0.0, -1.0, 0.0);

    var d = length(q.xz)
    - (6.9 - 0.1*q.y)

    // waves
    + sin(atan2(q.x, q.z)*15.0 + 4.0*t)*0.3
    + pow(sin(q.y*4.0 + t*4.1), 2.0)*0.5
    + q.y + 4.0
    + pow(sin(q.y*4.0), 3.0)*0.3
    ;

    // bounding sphere
    d = max(d, length(q) - 6.8 + sin(atan2(q.x, q.y) + t*5.0))
    + sin(atan2(q.x, q.z) + t*4.87)*0.4
    ;



    // plane clipping
    //d = max(d, -p.y - 4.0);
    d = max(d, p.y - 2.0);


    // cuboid thing
    let sdb = sd_box(q-v3f(0.0, 1.0, 0.0), v3f(1.0, 1.0, 1.0 + sin(t*3.0 + q.y + q.x))*2.0) - 1.0;
    d = smoothmin(d, sdb, 3.0);



    d = d*0.5*0.9;


    res = v3f( d, 1.0, res.z );
    return res.x;
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
            let tmax = 1000.0;
            var t = 0.0;
            for(var i=0; i<256; i = i+1) {
                let pos = ro + t*rd;
                let h = map(pos);
                if(h<0.0001*t || t>tmax) {break;}
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
            col = sqrt(col);
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

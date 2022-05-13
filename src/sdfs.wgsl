
// bigwings version
fn smin(a: f32, b: f32, k: f32) -> f32 { // -ve k for smax
    let h = clamp(0.5+0.5*(b-a)/k, 0.0, 1.0);
    return mix(b, a, h) - k*h*(1.0 - h);
}

// iq version
fn smoothmin(d_a: f32, d_b: f32, k: f32) -> f32 {
    let h = max(k-abs(d_a-d_b), 0.0)/k;
    return min(d_a, d_b) - h*h*h*k/6.0;
}

fn smoothmax(d_a: f32, d_b: f32, k: f32) -> f32 { // hopefully correct
    let h = max(k-abs(d_a-d_b), 0.0)/k;
    return max(d_a, d_b) + h*h*h*k/6.0;
}



fn sphere(pos: v3f, r: f32) -> f32 {
    return length(pos)-r;
}

fn u_box(p: v3f, b: v3f) -> f32{
    return length(max(abs(p)-b, v3f(0.0)));
}

fn box(p: v3f, b: v3f) -> f32 {
  let d = abs(p) - b;
  return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d, v3f(0.0)));
}

fn chocolate_fountain_blob_thing(p: v3f) -> f32 {
    var p = p;
    p = p + v3f(0.0, -2.0, 3.0);
    let op = p;

    p.y = p.y + 2.0;

    // bounding box
    let bbox = u_box(p,v3f(15.0,12.0,15.0)*1.5 );
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
    //d = max(d, -q.y - 4.0);
    d = max(d, q.y - 2.0);

    // cuboid thing
    let sdb = box(q-v3f(0.0, 1.0, 0.0), v3f(1.0, 1.0, 1.0 + sin(t*3.0 + q.y + q.x))*2.0) - 1.0;
    d = smoothmin(d, sdb, 3.0);
    // d = min(d, sdb);
    // d = sdb;

    // let plane_p = v3f(0.0);
    // let plane_n = normalize(v3f(-1.0, 0.0, -0.4));
    // d = max(d, dot(q - plane_p, plane_n));



    d = d*0.5*0.9;

    return d;
}


fn sdf_new(p: v3f) -> f32 {

    var p = p;
    p = p + v3f(0.0, 2.0, 6.0);

    let t = stuff.time;

    var d = 1e10;
    // var wave_p =  p.y + 1.0 - sin(p.x) - sin(p.z+t);
    // d = min(d, wave_p);

    let sphere_o = v3f(0.0, 2.0, -2.0);
    var sphere_r = 6.0;
    // sphere_r = sphere_r + perlin_noise(p.xy*4.0 + t).x*0.2-perlin_noise(p.xy*4.0 + -v2f(0.0, t)).x*0.2;
    var s = sphere(p-sphere_o, sphere_r);
    // d = s;

    var p_noise = 0.0;
    p_noise = p_noise + perlin_noise(p.xz*2.0 + v2f(t, 0.0)).y;
    p_noise = p_noise + perlin_noise(p.xz + v2f(-t, 0.0) + 00.0).y;
    var k = 14.0 - length(p.xz-sphere_o.xz);
    k = k/14.0;
    k = pow(k, 1.3);
    p_noise = p_noise*clamp(k, 0.0, 0.2)*2.5;
    p_noise = p.y - p_noise;
    // p_noise = p_noise + -7.0;
    // p_noise = abs(p_noise);
    // p_noise = max(0.00001, p_noise);
    d = min(d, p_noise);

    let e = 0.0;

    if (e < 0.5) {
        let q = p*2.5 + v3f(t);
        var gyroid = dot(sin(q)*0.7, cos(q.yzx))/1.0;
        gyroid = abs(gyroid) - 0.1;
        gyroid = max(s, gyroid);
        s = abs(s) - 0.5;
        gyroid = smoothmax(s, gyroid, 1.0);
        // d = min(d, gyroid);
        d = smoothmin(d, gyroid, 4.0);
        // d = gyroid;
    } else if (e < 1.5) {
        p = p*1.3 + t;
        var t = fract(p.x);
        // t = t*(1.0-t) - 0.1;
        var td = ((v3f(fract(p.x), fract(p.y), fract(p.z)) - v3f(1.0))*(v3f(fract(p.x), fract(p.y), fract(p.z))));
        t = dot(td, td);
        t = abs(t) - 0.1;
        d = min(smoothmax(t, s, 2.0), d);
    } else if (e < 2.5) {
        // failed attempt
        // https://en.wikipedia.org/wiki/Laves_graph
        var x = p.x*p.y*p.z;
        var e = 1e10;
        let a = atan2(p.x, p.z) + 0.1;
        let r = length(p.xz);
        p = v3f(r*sin(a), p.y, r*cos(a));
        p = fract(p);
        if (min(p.z, min(p.x, p.y)) < 0.5) {
            e = s;
        }
        // var e = smoothStep(-0.1, 0.1, x);
        // var e = smoothStep(x, -0.1, 0.1);
        e = max(s, e);
        // d = min(d, e);
        d = e;
    } else {
        d = smoothmin(d, s, 1.0);
        // d = max(d, s);
    }



    // d = abs(d);

    d = d*0.5;

    return d;
}



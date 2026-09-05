import Stripe from 'npm:stripe@17.7.0';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.112.4';
import { allowedOrigin, bearer, jsonHeaders, requestId, requirePost, safeErrorMessage } from '../_shared/security.ts';

const unitCents=(q:number)=>q>=10?349:q>=6?399:q>=3?449:499;
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

Deno.serve(async(req)=>{
  let origin=''; const rid=requestId(req);
  try{
    origin=allowedOrigin(req);
    if(req.method==='OPTIONS') return new Response(null,{status:204,headers:jsonHeaders(origin)});
    requirePost(req);

    const token=bearer(req);
    const supabaseUrl=Deno.env.get('SUPABASE_URL')!;
    const serviceKey=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const admin=createClient(supabaseUrl,serviceKey,{auth:{persistSession:false,autoRefreshToken:false}});
    const {data:{user},error:userError}=await admin.auth.getUser(token);
    if(userError||!user) throw new Error('AUTH_REQUIRED');

    const body=await req.json();
    const workspaceId=String(body.workspace_id||'');
    const quantity=Math.floor(Number(body.quantity||0));
    const clientRequestId=String(body.request_id||'');
    if(!uuid.test(workspaceId)||quantity<1||quantity>100||!uuid.test(clientRequestId)) throw new Error('INVALID_REQUEST');

    const bucket=`coorg-checkout:${user.id}:${workspaceId}`;
    const {data:ok,error:rlErr}=await admin.rpc('consume_security_rate_limit',{p_bucket_key:bucket,p_limit:8,p_window_seconds:600});
    if(rlErr||ok!==true) throw new Error('RATE_LIMIT');

    const {data:member,error:memberError}=await admin.from('workspace_members').select('role,active').eq('workspace_id',workspaceId).eq('user_id',user.id).maybeSingle();
    if(memberError||!member||member.active!==true||member.role!=='admin') throw new Error('ACCESS_DENIED');

    const appUrl=(Deno.env.get('SWE_APP_URL')||'').trim().replace(/\/$/,'');
    if(!/^https:\/\//.test(appUrl)) throw new Error('SECURITY_CONFIG_MISSING');
    const successUrl=`${appUrl}/?coorg=success`;
    const cancelUrl=`${appUrl}/?coorg=cancel`;

    const stripe=new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!,{apiVersion:'2024-12-18.acacia'});
    const unit=unitCents(quantity);
    const session=await stripe.checkout.sessions.create({
      mode:'subscription',
      customer_email:user.email||undefined,
      client_reference_id:workspaceId,
      line_items:[{quantity,price_data:{currency:'eur',unit_amount:unit,recurring:{interval:'month'},product_data:{name:'SWÉ — Co-gestionnaire supplémentaire',description:`${quantity} accès co-gestionnaire(s) supplémentaire(s)`}}}],
      success_url:successUrl,
      cancel_url:cancelUrl,
      allow_promotion_codes:false,
      metadata:{type:'swe_coorganizers',workspace_id:workspaceId,quantity:String(quantity),unit_amount_cents:String(unit),request_id:clientRequestId,actor_user_id:user.id},
      subscription_data:{metadata:{type:'swe_coorganizers',workspace_id:workspaceId,quantity:String(quantity),unit_amount_cents:String(unit),request_id:clientRequestId,actor_user_id:user.id}},
    },{idempotencyKey:`swe-coorg-${workspaceId}-${clientRequestId}`});

    await admin.from('security_audit_log').insert({workspace_id:workspaceId,actor_user_id:user.id,actor_type:'user',action:'billing.coorganizer_checkout_created',target_type:'checkout_session',target_id:session.id,request_id:rid,metadata:{quantity,unit_amount_cents:unit}});
    return Response.json({url:session.url,request_id:rid},{headers:jsonHeaders(origin)});
  }catch(e){
    console.error('[stripe-create-coorganizer-checkout]',rid,e);
    const headers=origin?jsonHeaders(origin):{'Content-Type':'application/json','Cache-Control':'no-store'};
    const status=(e instanceof Error&&e.message==='ORIGIN_NOT_ALLOWED')?403:400;
    return Response.json({error:safeErrorMessage(e),request_id:rid},{status,headers});
  }
});

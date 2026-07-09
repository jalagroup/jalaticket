// supabase/functions/delete-user-admin/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const ALLOWED_CALLER_ROLES = [
  'system_admin',
  'super_admin',
  'super_user',
  'branch_admin',
]

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    // ── Verify caller ──────────────────────────────────────────────────────
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, message: 'No authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const token = authHeader.replace('Bearer ', '')
    const { data: { user: caller }, error: authError } =
      await supabaseAdmin.auth.getUser(token)

    if (authError || !caller) {
      return new Response(
        JSON.stringify({ success: false, message: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { data: callerProfile } = await supabaseAdmin
      .from('users')
      .select('user_type, is_active')
      .eq('auth_id', caller.id)
      .single()

    if (
      !callerProfile ||
      !ALLOWED_CALLER_ROLES.includes(callerProfile.user_type) ||
      !callerProfile.is_active
    ) {
      return new Response(
        JSON.stringify({ success: false, message: 'Admin access required' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ── Parse target user ──────────────────────────────────────────────────
    const { userId } = await req.json()
    if (!userId) {
      return new Response(
        JSON.stringify({ success: false, message: 'userId is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Fetch the target user's DB row to get their auth_id
    const { data: targetUser, error: userFetchError } = await supabaseAdmin
      .from('users')
      .select('id, auth_id, email, full_name')
      .eq('id', userId)
      .single()

    if (userFetchError || !targetUser) {
      return new Response(
        JSON.stringify({ success: false, message: 'User not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ── Check if user has any records in the system ────────────────────────
    const checks = await Promise.all([
      // Tickets they created
      supabaseAdmin
        .from('tickets')
        .select('id', { count: 'exact', head: true })
        .eq('created_by', userId),

      // Tickets assigned to them
      supabaseAdmin
        .from('tickets')
        .select('id', { count: 'exact', head: true })
        .eq('assigned_to', userId),

      // Ticket reports they wrote
      supabaseAdmin
        .from('ticket_reports')
        .select('id', { count: 'exact', head: true })
        .eq('created_by', userId),

      // Complaints they filed
      supabaseAdmin
        .from('complaints')
        .select('id', { count: 'exact', head: true })
        .eq('created_by', userId),

      // Problem reports they submitted
      supabaseAdmin
        .from('problem_reports')
        .select('id', { count: 'exact', head: true })
        .eq('user_id', userId),

      // Activity log entries
      supabaseAdmin
        .from('activity_logs')
        .select('id', { count: 'exact', head: true })
        .eq('user_id', userId),
    ])

    const totalRecords = checks.reduce((sum, result) => sum + (result.count ?? 0), 0)
    const hasRecords = totalRecords > 0

    if (hasRecords) {
      // ── Soft delete: deactivate and hide ────────────────────────────────
      const { error: deactivateError } = await supabaseAdmin
        .from('users')
        .update({ is_active: false, is_deleted: true })
        .eq('id', userId)

      if (deactivateError) throw deactivateError

      return new Response(
        JSON.stringify({
          success: true,
          action: 'deactivated',
          message: 'User has existing records and was deactivated',
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    } else {
      // ── Hard delete: remove from DB then from auth ───────────────────────

      // Delete notifications (user-scoped, safe to remove)
      await supabaseAdmin.from('notifications').delete().eq('user_id', userId)
      await supabaseAdmin.from('notification_preferences').delete().eq('user_id', userId)

      // Delete the profile row
      const { error: dbDeleteError } = await supabaseAdmin
        .from('users')
        .delete()
        .eq('id', userId)

      if (dbDeleteError) throw dbDeleteError

      // Delete from Supabase Auth (requires service role)
      if (targetUser.auth_id) {
        const { error: authDeleteError } =
          await supabaseAdmin.auth.admin.deleteUser(targetUser.auth_id)
        if (authDeleteError) throw authDeleteError
      }

      return new Response(
        JSON.stringify({
          success: true,
          action: 'deleted',
          message: 'User permanently deleted',
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, message: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

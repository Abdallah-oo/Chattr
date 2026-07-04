import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { initializeApp, cert } from 'npm:firebase-admin/app'
import { getMessaging } from 'npm:firebase-admin/messaging'

// 1. تهيئة Firebase
const firebaseServiceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') || '{}')
try {
  initializeApp({ credential: cert(firebaseServiceAccount) })
} catch (error: any) {
  if (!/already exists/.test(error.message)) {
    console.error('Firebase init error', error.stack)
  }
}

serve(async (req) => {
  try {
    const payload = await req.json()
    const message = payload.record
    const tableName = payload.table

    if (!message || !message.content) {
      return new Response('No message content', { status: 200 })
    }

    // 2. تهيئة Supabase Client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 3. جلب اسم المرسل
    const { data: sender } = await supabaseClient
      .from('messenger_users')
      .select('name')
      .eq('id', message.sender_id)
      .single()
    const senderName = sender?.name || 'New Message'

    let tokens: string[] = []
    let notificationTitle = senderName
    let notificationBody = message.content

    switch (message.message_type) {
      case 'image':
        notificationBody = '📷 Image'
        break

      case 'video':
        notificationBody = '🎥 Video'
        break

      case 'voice':
        notificationBody = '🎤 Voice message'
        break

      case 'text':
        notificationBody = message.content
        break

      default:
        notificationBody = message.content ?? 'New Message'
    }
    let chatIdData = ''
    let chatType = ''

    // ==========================================
    // مسار الشات الخاص (Private Chats)
    // ==========================================
    if (tableName === 'message') {
      const { data: chat } = await supabaseClient
        .from('private_chats')
        .select('members')
        .eq('chat_id', message.chat_id)
        .single()

      const receiverId = chat?.members?.find((id: string) => id !== message.sender_id)

      if (receiverId) {
        const { data: receiver } = await supabaseClient
          .from('messenger_users')
          .select('fcm_token')
          .eq('id', receiverId)
          .single()

        if (receiver?.fcm_token) tokens.push(receiver.fcm_token)
      }

      chatIdData = message.chat_id
      chatType = 'private_message'

      // ==========================================
      // مسار الشات الجماعي (Group Chats)
      // ==========================================
    } else if (tableName === 'group_messages') {
      // أ. جلب اسم الجروب عشان يظهر في عنوان الإشعار (مثال: Flutter Team - Abdallah)
      const { data: group } = await supabaseClient
        .from('groups')
        .select('name')
        .eq('group_id', message.group_id)
        .single()

      notificationTitle = `${group?.name} - ${senderName}`

      // ب. جلب كل أعضاء الجروب ما عدا المرسل
      const { data: groupMembers } = await supabaseClient
        .from('group_members')
        .select('user_id')
        .eq('group_id', message.group_id)

      if (groupMembers) {
        const memberIds = groupMembers
          .map((m: any) => m.user_id)
          .filter((id: string) => id !== message.sender_id)

        // ج. جلب الـ FCM Tokens الخاصة بالأعضاء دول
        if (memberIds.length > 0) {
          const { data: users } = await supabaseClient
            .from('messenger_users')
            .select('fcm_token')
            .in('id', memberIds)

          if (users) {
            tokens = users.map((u: any) => u.fcm_token).filter((t: any) => t != null)
          }
        }
      }

      chatIdData = message.group_id
      chatType = 'group_message'
    }

    // 4. التأكد إن فيه Tokens هنبعتلها
    if (tokens.length === 0) {
      console.log('No valid FCM tokens found for receivers.')
      return new Response('No receivers with FCM tokens', { status: 200 })
    }

    // 5. إرسال الإشعار الجماعي (Multicast) لفايربيز
    const fcmPayload = {
      tokens: tokens, // بياخد Array of tokens
      notification: {
        title: notificationTitle,
        body: notificationBody,
      },
      data: {
        chatId: chatIdData,
        type: chatType,
      },
    }

    // sendEachForMulticast ممتازة لأنها بتبعت لكذا شخص في نفس الوقت
    const response = await getMessaging().sendEachForMulticast(fcmPayload)
    console.log('Successfully sent messages:', response.successCount)

    return new Response(JSON.stringify({ success: true, sentCount: response.successCount }), {
      headers: { 'Content-Type': 'application/json' },
    })

  } catch (error) {
    console.error('Error in function:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
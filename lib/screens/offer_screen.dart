import 'package:flutter/material.dart';

import '../config/brand_theme.dart';
import '../l10n/app_strings.dart';
import '../services/billing_service.dart';
import '../widgets/unlumen/murkot_fx.dart';

/// Public offer + payment disclosure for YooKassa moderation.
class OfferScreen extends StatelessWidget {
  const OfferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRu = context.strings.isRu;

    return Scaffold(
      appBar: AppBar(
        leading: const MurkotBackButton(),
        title: Text(isRu ? 'Оферта и платежи' : 'Terms & Payments'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Text(
            isRu ? 'Платежи на сайте' : 'Payments on the site',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isRu
                ? 'Оплата цифровых услуг Murkot проходит через ЮKassa. Ниже — то, что нужно для приёма платежей: товары, доставка, оферта и реквизиты.'
                : 'Murkot digital services are paid via YooKassa. Below: products, delivery, offer and contacts.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          _Section(
            title: isRu
                ? 'Настоящие товары или услуги, цены, описания'
                : 'Real products, prices, descriptions',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRu
                      ? 'На сайте размещены именно те услуги, за которые принимается оплата. Информация актуальная, цены фиксированные.'
                      : 'The site lists the exact services you pay for, with fixed prices.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                for (final p in kMurkotCatalog) ...[
                  _ProductRow(info: p, isRu: isRu),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          _Section(
            title: isRu
                ? 'Способы доставки / получения заказа'
                : 'Delivery / order fulfillment',
            child: Text(
              isRu
                  ? 'Услуги цифровые. После успешной оплаты доступ активируется мгновенно в аккаунте (подписка Plus / Кабинет HR / буст объявления). Подтверждение приходит на email аккаунта и отображается в профиле. Физическая доставка не требуется.'
                  : 'Digital goods only. Access activates instantly after payment in your account. Confirmation goes to your account email. No physical shipping.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          _Section(
            title: isRu
                ? 'Пользовательское соглашение (публичная оферта)'
                : 'User agreement (public offer)',
            child: Text(
              isRu
                  ? '''1. Исполнитель: самозанятый «Иванов Иван Иванович» (заглушка), ИНН 123456789012 (заглушка), далее — Murkot.
2. Заказчик — пользователь, прошедший регистрацию в сервисе Murkot.
3. Предмет: предоставление доступа к цифровым услугам (подписки, бусты объявлений) согласно выбранному тарифу.
4. Акцепт оферты — нажатие «Оплатить» и успешная оплата через ЮKassa.
5. Срок оказания: доступ активируется сразу после подтверждения платежа.
6. Возврат: в течение 7 календарных дней, если услуга не была оказана по вине исполнителя. Для подписок — пропорциональный возврат неиспользованного периода по обращению в поддержку.
7. Запрещено: обход ограничений, спам, покупка бустов для запрещённого контента.
8. Споры решаются путём переговоров, затем по месту регистрации исполнителя.

Полный текст оферты уточняется перед продакшен-запуском платежей; сейчас указаны заглушки реквизитов.'''
                  : '''1. Provider: self-employed placeholder “Ivanov I.I.”, INN placeholder.
2. Customer: registered Murkot user.
3. Subject: digital access (subscriptions, listing boosts).
4. Acceptance: tapping Pay and completing YooKassa checkout.
5. Delivery: instant after payment confirmation.
6. Refunds: within 7 days if the service was not delivered.
7. Prohibited: spam, abuse, boosting banned content.

Legal placeholders will be replaced before production payments.''',
              style: theme.textTheme.bodySmall,
            ),
          ),
          _Section(
            title: isRu ? 'Контакты и реквизиты' : 'Contacts & details',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ContactLine(
                  icon: Icons.person_outline,
                  text: isRu
                      ? 'ФИО: Иванов Иван Иванович (заглушка)'
                      : 'Full name: Ivanov Ivan Ivanovich (placeholder)',
                ),
                _ContactLine(
                  icon: Icons.badge_outlined,
                  text: isRu
                      ? 'ИНН: 123456789012 (заглушка)'
                      : 'INN: 123456789012 (placeholder)',
                ),
                _ContactLine(
                  icon: Icons.email_outlined,
                  text: 'Email: support@murkot.space (заглушка)',
                ),
                _ContactLine(
                  icon: Icons.phone_outlined,
                  text: isRu
                      ? 'Телефон: +7 (999) 123-45-67 (заглушка)'
                      : 'Phone: +7 (999) 123-45-67 (placeholder)',
                ),
                _ContactLine(
                  icon: Icons.home_outlined,
                  text: isRu
                      ? 'Почтовый адрес: 000000, г. Москва, ул. Примерная, д. 1 (заглушка)'
                      : 'Postal address: Moscow, Example st. 1 (placeholder)',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: MurkotColors.orange,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check),
            label: Text(isRu ? 'Принимаю' : 'Accept'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.info, required this.isRu});

  final MurkotProductInfo info;
  final bool isRu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(info.icon, size: 18, color: MurkotColors.orange),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${info.title(isRu)} — ${info.priceLabel(isRu)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                info.description(isRu),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

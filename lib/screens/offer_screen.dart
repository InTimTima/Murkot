import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../widgets/unlumen/murkot_fx.dart';

class OfferScreen extends StatelessWidget {
  const OfferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRu = context.strings.isRu;
    return Scaffold(
      appBar: AppBar(leading: const MurkotBackButton(), title: Text(isRu ? 'Оферта и платежи' : 'Terms & Payments')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(isRu ? 'Платежи на сайте' : 'Payments', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(isRu ? 'Подходит, если вы работаете на своём сайте или через системы записи YClients и DIKIDI. Работаем через ЮKassa.' : 'Via YooKassa.'),
          const SizedBox(height: 16),
          _Section(title: isRu ? 'Настоящие товары или услуги, цены, описания' : 'Real goods, prices, descriptions', body: isRu ? 'На сайте размещены именно те товары/услуги, за которые принимается оплата: Murkot Plus 399 ₽/мес, бусты 50/150/99/999 ₽, Кабинет HR 24 999 ₽/мес. Цены фиксированные, описания актуальные. Если без фикс. цены — выставление счёта.' : 'All goods listed with fixed prices.'),
          _Section(title: isRu ? 'Информацию о способах доставки или получения заказа' : 'Delivery', body: isRu ? 'Доставка — онлайн-доступ к подписке/бусту сразу после оплаты. Письмо на почту и в профиль. Срок активации — мгновенно.' : ' Instant online delivery.'),
          _Section(title: isRu ? 'Пользовательское соглашение или оферту' : 'User agreement', body: isRu ? 'Нажимая Оплатить, вы соглашаетесь с офертой: исполнитель — Murkot, предоставляет доступ к цифровым услугам. Возврат в течение 7 дней если услуга не оказана. Публичная оферта размещена по этому адресу.' : 'By paying you accept the offer.'),
          _Section(title: isRu ? 'Контакты и реквизиты' : 'Contacts', body: isRu ? 'Связь: support@murkot.space, +7 (999) 123-45-67, ИНН и ФИО самозанятого — Иванов И.И., ИНН 123456789012.' : 'support@murkot.space'),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.check), label: Text(isRu ? 'Принимаю' : 'Accept')),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});
  final String title; final String body;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(body, style: theme.textTheme.bodySmall),
      ])),
    );
  }
}

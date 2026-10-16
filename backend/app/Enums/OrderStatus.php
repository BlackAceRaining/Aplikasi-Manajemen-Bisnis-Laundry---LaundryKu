<?php

namespace App\Enums;

enum OrderStatus: string
{
    case Diterima = 'Diterima';
    case Ditimbang = 'Ditimbang';
    case Dicuci = 'Dicuci';
    case Disetrika = 'Disetrika';
    case Siap = 'Siap';
    case Diambil = 'Diambil';
    case Lunas = 'Lunas';
    case Selesai = 'Selesai';
    case TidakDiambil = 'Tidak Diambil';
    case Dibatalkan = 'Dibatalkan';

    /**
     * Return valid standard forward transitions.
     *
     * @return array<string, array<string>>
     */
    public static function allowedTransitions(): array
    {
        return [
            self::Diterima->value => [self::Ditimbang->value, self::Dibatalkan->value],
            self::Ditimbang->value => [self::Dicuci->value, self::Dibatalkan->value],
            self::Dicuci->value => [self::Disetrika->value],
            self::Disetrika->value => [self::Siap->value],
            self::Siap->value => [self::Diambil->value, self::TidakDiambil->value],
            self::Diambil->value => [self::Lunas->value],
            self::Lunas->value => [self::Selesai->value],
            self::Selesai->value => [],
            self::TidakDiambil->value => [],
            self::Dibatalkan->value => [],
        ];
    }

    /**
     * Check if transition from this status to target is forward.
     */
    public function canTransitionTo(OrderStatus $target): bool
    {
        $allowed = self::allowedTransitions()[$this->value] ?? [];
        return in_array($target->value, $allowed, true);
    }
}
